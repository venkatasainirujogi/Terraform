

# 1️ VPC creation
resource "aws_vpc" "name" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

# 2️ Internet Gateway creation
resource "aws_internet_gateway" "name" {
  vpc_id = aws_vpc.name.id

  tags = {
    Name = "main-igw"
  }
}

# 3️ Public subnet-1
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public_subnet-1"
  }
}

# 4️ Public subnet-2
resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "public_subnet-2"
  }
}

# 5️ Frontend-1 subnet
resource "aws_subnet" "frontend_1" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "frontend-1"
  }
}

# 6️ Frontend-2 subnet
resource "aws_subnet" "frontend_2" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "frontend-2"
  }
}

# 7️  Backend-1 subnet
resource "aws_subnet" "backend_1" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "backend-1"
  }
}

# 8️  Backend-2 subnet
resource "aws_subnet" "backend_2" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "backend-2"
  }
}

# 9️ DC-DB subnet
resource "aws_subnet" "dc_db" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "dc-db"
  }
}

# 10️  DR-DB subnet
resource "aws_subnet" "dr_db" {
  vpc_id            = aws_vpc.name.id
  cidr_block        = "10.0.7.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "dr-db"
  }
}

# 11️  Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.name.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.name.id
  }

  tags = {
    Name = "projectK-public-rt"
  }
}

# 12️  Associate public route table with public subnets
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 1️3 Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# 14 NAT Gateway in public subnet-1
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "projectK-nat-gw"
  }
  depends_on = [ aws_internet_gateway.name ]
}

# 15 Private Route Table for private subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.name.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "projectK-private-rt"
  }
}

# 16 Associate private route table with frontend/backend/DB subnets
resource "aws_route_table_association" "private_assoc" {
  count          = 6
  subnet_id      = element([
    aws_subnet.frontend_1.id,
    aws_subnet.frontend_2.id,
    aws_subnet.backend_1.id,
    aws_subnet.backend_2.id,
    aws_subnet.dc_db.id,
    aws_subnet.dr_db.id
  ], count.index)
  route_table_id = aws_route_table.private_rt.id
}
# 17 Security Group for Bastion (SSH from my IP only)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH access from my IP only"
  vpc_id      = aws_vpc.name.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.25/32"]  
  }

# this tells allow all the traffic from outside
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}
# 18 froent-end Security Group for (aTTACHED bastionsG)
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP and SSH from bastion"
  vpc_id      = aws_vpc.name.id

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-sg"
  }
}

# 19 BACKEND SECURITY GROUP (ALLOW ONLY FROEND-SG)

resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow traffic only from frontend servers"
  vpc_id      = aws_vpc.name.id

  # Allow SSH from frontend servers only (optional)
  ingress {
    description     = "SSH from frontend servers"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  # Allow app traffic from frontend servers
  ingress {
    description     = "App traffic from frontend servers"
    from_port       = 8080   # replace with your app port
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  # Outbound traffic to anywhere (allow backend to access internet via NAT if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}
# 20 Security Group for RDS (DC-DB / DR-DB)

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow DB traffic only from backend servers"
  vpc_id      = aws_vpc.name.id

  # Allow MySQL/PostgreSQL traffic (example port 3306 for MySQL) from backend servers only
  ingress {
    description     = "DB access from backend servers"
    from_port       = 3306       ##MYSQL PORT NUMBER
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  # Outbound traffic (allow DB to communicate if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}


# 21 Create Security Group for ALB

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.name.id

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS (optional)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}


# 22 Bastion Host in Public Subnet-1

resource "aws_instance" "bastion" {
  ami                         = "ami-0c02fb55956c7d316"  # Amazon Linux 2
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true  # Public IP needed for SSH access

  tags = {
    Name = "bastion-host"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y git
              EOF
}


#  Create Application Load Balancer
# 23 Frontend Servers
resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.frontend_1.id, aws_subnet.frontend_2.id] # public subnets

  enable_deletion_protection = false
  tags = { Name = "frontend-alb" }
}

#target group creation
resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.name.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = { Name = "frontend-tg" }
}
#Register frontend servers with Target Group
resource "aws_lb_target_group_attachment" "frontend_1" {
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "frontend_2" {
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend_2.id
  port             = 80
}
#Create Listener for ALB
resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}



# Launch Template for Frontend

resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "frontend-lt-"
  image_id      = "ami-0c02fb55956c7d316"  # Amazon Linux 2
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  user_data = <<-EOF
              #!/bin/bash                    
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF
                                                            #by instace launching it will install apache
  tag_specifications {
    resource_type = "instance"
    tags = { Name = "frontend-instance" }
  }
}
# Backend Launch Template for backend servers
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "backend-lt-"
  image_id      = "ami-0c02fb55956c7d316" 
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "backend-instance" }
  }
}

# Frontend Auto Scaling Group
resource "aws_autoscaling_group" "frontend_asg" {
  name                = "frontend-asg"
  max_size            = 3
  min_size            = 1
  desired_capacity    = 1
  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.frontend_1.id, aws_subnet.frontend_2.id]
  health_check_type   = "EC2"
  force_delete        = true
  target_group_arns   = [aws_lb_target_group.frontend_tg.arn]

  tag {
    key                 = "Name"
    value               = "frontend-asg"
    propagate_at_launch = true
  }
}
 # backend Auto Scaling Group
resource "aws_autoscaling_group" "backend_asg" {
  name                = "backend-asg"
  max_size            = 3
  min_size            = 1
  desired_capacity    = 1
  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.backend_1.id, aws_subnet.backend_2.id]
  health_check_type   = "EC2"
  force_delete        = true

  tag {
    key                 = "Name"
    value               = "backend-asg"
    propagate_at_launch = true
  }
}
 #  froent end Servers
resource "aws_instance" "frontend_1" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.frontend_1.id
  vpc_security_group_ids      = [aws_security_group.frontend_sg.id]
  associate_public_ip_address = false
  tags = { Name = "frontend-1" }
}

resource "aws_instance" "frontend_2" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.frontend_2.id
  vpc_security_group_ids      = [aws_security_group.frontend_sg.id]
  associate_public_ip_address = false
  tags = { Name = "frontend-2" }
}

# 24 Backend Servers

resource "aws_instance" "backend_1" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.backend_1.id
  vpc_security_group_ids      = [aws_security_group.backend_sg.id]
  associate_public_ip_address = false
  tags = { Name = "backend-1" }
}

resource "aws_instance" "backend_2" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.backend_2.id
  vpc_security_group_ids      = [aws_security_group.backend_sg.id]
  associate_public_ip_address = false
  tags = { Name = "backend-2" }
}

# 25 DB Subnet Group (for RDS instances)

resource "aws_db_subnet_group" "projectk_db_subnet_group" {
  name       = "projectk-db-subnet-group"
  subnet_ids = [aws_subnet.dc_db.id, aws_subnet.dr_db.id]
  tags       = { Name = "projectk-db-subnet-group" }
}


# 26 RDS Instances for "primary_db"

resource "aws_db_instance" "primary_db" {
  identifier             = "dc-db-instance"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "admin"
  password               = "Admin1234"
  skip_final_snapshot    = true
  publicly_accessible    = false
  backup_retention_period = 7
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.projectk_db_subnet_group.name
  multi_az               = false
  tags                   = { Name = "dc-db-instance" }
}
 # 26 RDS Instances for "secondary_db"
resource "aws_db_instance" "secondary_db" {
  identifier             = "dr-db-instance"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "admin"
  password               = "Admin1234"
  backup_retention_period = 7
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.projectk_db_subnet_group.name
  multi_az               = false
  tags                   = { Name = "dr-db-instance" }
}
# Read Replica for DC RDS
resource "aws_db_instance" "dc_read_replica" {
  identifier          = "dc-db-replica"
  instance_class      = "db.t3.micro"
  replicate_source_db = aws_db_instance.primary_db.id
  db_subnet_group_name = aws_db_subnet_group.projectk_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible = false
  tags = { Name = "dc-db-replica" }
}

# Read Replica for DR RDS
resource "aws_db_instance" "dr_read_replica" {
  identifier          = "dr-db-replica"
  instance_class      = "db.t3.micro"
  replicate_source_db = aws_db_instance.secondary_db.id
  db_subnet_group_name = aws_db_subnet_group.projectk_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible = false
  tags = { Name = "dr-db-replica" }
}


