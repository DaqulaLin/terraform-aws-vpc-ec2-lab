resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

#Public subnets
resource "aws_subnet" "public" {
  for_each = { for idx, az in var.public_subnets : idx => az }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = { Name = "${var.name_prefix}-public-${each.key}" }
}

#Private subnets
resource "aws_subnet" "private" {
  for_each = { for idx, az in var.private_subnets : idx => az }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.azs[tonumber(each.key)]

  tags = { Name = "${var.name_prefix}-private-${each.key}" }
}

#Put NAT on the first public subnet
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = var.enable_nat ? aws_eip.nat[0].id : null
  subnet_id     = var.enable_nat ? values(aws_subnet.public)[0].id : null
  tags          = { Name = "${var.name_prefix}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}


#Public route table: to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# Private route table: to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-private-rt" }
}

resource "aws_route" "private_default_via_nat" {
  count                  = var.enable_nat ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
