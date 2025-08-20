variable "state_bucket_name" {
  type        = string
  description = "Remote state S3 Bucket name (must be globally unique)"
}


variable "lock_table_name" {
  type        = string
  description = "DynamoDB table name,use for state locking"
  default     = "tf-locks"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"

}
