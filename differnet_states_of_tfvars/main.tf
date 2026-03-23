
# 1. NETWORKING LAYER (VPC, Subnets, IGW, NAT)

resource "aws_vpc" "name" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "name" {
  vpc_id = aws_vpc.name.id
  tags   = { Name = "main-igw" }
}

# Public Subnets (For Bastion & Public ALB)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-2" }
}

# Private Subnets (Frontend App)
resource "aws_subnet" "frontend_1" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "frontend-1" }
}

resource "aws_subnet" "frontend_2" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1b"
  tags = { Name = "frontend-2" }
}

# Private Subnets (Backend App & Internal ALB)
resource "aws_subnet" "backend_1" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "backend-1" }
}

resource "aws_subnet" "backend_2" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-south-1b"
  tags = { Name = "backend-2" }
}

# Private Subnets (Database)
resource "aws_subnet" "dc_db" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "db-1" }
}

resource "aws_subnet" "dr_db" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.7.0/24"
  availability_zone = "ap-south-1b"
  tags = { Name = "db-2" }
}

# NAT Gateway logic
resource "aws_eip" "nat_eip" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.name]
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.name.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.name.id
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.name.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "pub" {
  count          = 2
  subnet_id      = [aws_subnet.public_1.id, aws_subnet.public_2.id][count.index]
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "priv" {
  count     = 6
  subnet_id = [
    aws_subnet.frontend_1.id, aws_subnet.frontend_2.id,
    aws_subnet.backend_1.id, aws_subnet.backend_2.id,
    aws_subnet.dc_db.id, aws_subnet.dr_db.id
  ][count.index]
  route_table_id = aws_route_table.private_rt.id
}

# 2. SECURITY GROUPS 


# 1. Public ALB SG
resource "aws_security_group" "public_alb_sg" {
  name   = "public-alb-sg"
  vpc_id = aws_vpc.name.id
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Frontend Instances SG
resource "aws_security_group" "frontend_sg" {
  name   = "frontend-sg"
  vpc_id = aws_vpc.name.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb_sg.id]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Internal Backend ALB SG
resource "aws_security_group" "internal_alb_sg" {
  name   = "internal-alb-sg"
  vpc_id = aws_vpc.name.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Backend Instances SG
resource "aws_security_group" "backend_sg" {
  name   = "backend-sg"
  vpc_id = aws_vpc.name.id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb_sg.id]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Database SG
resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = aws_vpc.name.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
}


# 3. LOAD BALANCERS & AUTO SCALING

# --- FRONTEND TIER ---
resource "aws_lb" "public_alb" {
  name               = "public-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "frontend_tg" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.name.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.public_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "frontend-lt-"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  user_data = base64encode("#!/bin/bash\nyum update -y\nyum install -y httpd\nsystemctl start httpd\nsystemctl enable httpd")
}

resource "aws_autoscaling_group" "frontend_asg" {
  vpc_zone_identifier = [aws_subnet.frontend_1.id, aws_subnet.frontend_2.id]
  target_group_arns   = [aws_lb_target_group.frontend_tg.arn]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }
}

# --- BACKEND TIER ---
resource "aws_lb" "internal_alb" {
  name               = "internal-backend-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb_sg.id]
  subnets            = [aws_subnet.backend_1.id, aws_subnet.backend_2.id]
}

resource "aws_lb_target_group" "backend_tg" {
  name     = "backend-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.name.id
}

resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

resource "aws_launch_template" "backend_lt" {
  name_prefix   = "backend-lt-"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
}

resource "aws_autoscaling_group" "backend_asg" {
  vpc_zone_identifier = [aws_subnet.backend_1.id, aws_subnet.backend_2.id]
  target_group_arns   = [aws_lb_target_group.backend_tg.arn]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }
}


# 4. DATABASE LAYER

resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.dc_db.id, aws_subnet.dr_db.id]
}

resource "aws_db_instance" "primary" {
  identifier              = "projectk-primary-db"
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = "admin"
  password                = "Admin1234"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  backup_retention_period = 7
  skip_final_snapshot     = true
}

resource "aws_db_instance" "replica" {
  identifier             = "projectk-replica-db"
  replicate_source_db    = aws_db_instance.primary.identifier
  instance_class         = "db.t3.micro"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  depends_on             = [aws_db_instance.primary]
}

