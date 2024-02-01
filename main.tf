resource "aws_vpc" "demo-myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "demo-sub1" {
  vpc_id                  = aws_vpc.demo-myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "demo-sub2" {
  vpc_id                  = aws_vpc.demo-myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "demo-igw" {
  vpc_id = aws_vpc.demo-myvpc.id
}

resource "aws_route_table" "demo-rt" {
  vpc_id = aws_vpc.demo-myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }
}

resource "aws_route_table_association" "demo-rta1" {
  subnet_id      = aws_subnet.demo-sub1.id
  route_table_id = aws_route_table.demo-rt.id
}

resource "aws_route_table_association" "demo-rta2" {
  subnet_id      = aws_subnet.demo-sub2.id
  route_table_id = aws_route_table.demo-rt.id
}

resource "aws_security_group" "demo-mysg" {
  name   = "demo-web-sg"
  vpc_id = aws_vpc.demo-myvpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "demo-web-sg"
  }
}

resource "aws_s3_bucket" "demo-s3-bucket" {
  bucket = "jagat-my-bucket"
}

resource "aws_instance" "demo-webserver1" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.demo-mysg.id]
  subnet_id              = aws_subnet.demo-sub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "demo-webserver2" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.demo-mysg.id]
  subnet_id              = aws_subnet.demo-sub2.id
  user_data              = base64encode(file("userdata1.sh"))
}

#create the alb (application load balancer)
resource "aws_lb" "demo-myalb" {
  name               = "demo-myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.demo-mysg.id]
  subnets         = [aws_subnet.demo-sub1.id, aws_subnet.demo-sub2.id]

  tags = {
    Name = "web"
  }
}

//Create the load balancer target group
resource "aws_lb_target_group" "demo-tg" {
  name     = "my-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo-myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

//Attach the 1st instace to target group
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.demo-tg.arn
  target_id        = aws_instance.demo-webserver1.id
  port             = 80
}

//Attach the 2nd instace to target group
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.demo-tg.arn
  target_id        = aws_instance.demo-webserver2.id
  port             = 80
}

//attach target group to loadbalancer
resource "aws_lb_listener" "name" {
  load_balancer_arn = aws_lb.demo-myalb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.demo-tg.arn
    type             = "forward"
  }
}

//Output the loadbalancer dns name
output "loadbalancerdns" {
  value = aws_lb.demo-myalb.dns_name
}


