//provider
provider "aws" {
	region = "ap-south-1"
	access_key = "AKIARVYCIJ3CHBXMVNSV"
        secret_key = "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"
}

//Creating instance
resource "aws_instance" "instance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task1_key"
  security_groups = ["allow_80"] 
  
  //connection to the instance
  connection {
  type     = "ssh"
  user     = "ec2-user"
  private_key = "${tls_private_key.key1.private_key_pem}"
  host     = aws_instance.instance.public_ip
  }

  //Remote Login and Starting Services
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "task1"
  }
}

//Creating Key-pair
resource "tls_private_key" "key1" {
 algorithm = "RSA"
 rsa_bits = 4096
}

resource "local_file" "key"{
 content = "${tls_private_key.key1.private_key_pem}"
 filename = "task1_key.pem"
 file_permission = 0400
}

resource "aws_key_pair" "key3" {
 key_name = "task1_key"
 public_key = "${tls_private_key.key1.public_key_openssh}"
}

//Create Security Group
resource "aws_security_group" "allow_80" {
  name        = "allow_80"
  description = "Allow 80 inbound traffic"
  vpc_id      = "vpc-3f968b57"

  ingress {
    description = "allow https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "allow ssh"
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
    Name = "allow_80"
  }
}

//Attach Volume
resource "aws_volume_attachment" "vol_attach" {
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.vol.id}"
  instance_id = "${aws_instance.instance.id}"
  force_detach = true
}

//Create Volume
resource "aws_ebs_volume" "vol" {
  availability_zone = aws_instance.instance.availability_zone
  size              = 1
}

//Store PublicIp in .txt file 
resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.instance.public_ip} > publicip.txt"
  	}
}


//Create Bucket
resource "aws_s3_bucket" "mybucket" {
  bucket = "navs-nick"
  acl = "public-read"
  force_destroy = "true"
  versioning{
   enabled = true
  }
}

//Upload Image on Bucket
resource "aws_s3_bucket_object" "object" {
  depends_on = [
    aws_s3_bucket.mybucket,
  ]
  bucket = "navs-nick"
  key    = "img.jpg"
  source = "C:/Users/Nick/Desktop/nick/sush.jpg"
  acl    = "public-read"
  
}


//Print IP
output  "ip" {
	value = aws_instance.instance.public_ip
}



//Create CloudFront
resource "aws_cloudfront_distribution" "nick-cloudfront" {
    origin {
        domain_name = "task1.s3.amazonaws.com"
        origin_id = "S3-task1" 


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-task1"


        # Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }


    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.vol_attach,
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.key1.private_key_pem}"
    host     = aws_instance.instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/nickk99/task1_hybrid_cloud.git /var/www/html/",
      "sudo cp -vfr /var/www/html/  /nick/",  
    ]
  }
}


//Open Website on Chrome Browser
resource "null_resource" "nulllocal1"  {
depends_on = [
    null_resource.nullremote3,
  ]
	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.instance.public_ip}"
  	}
}

