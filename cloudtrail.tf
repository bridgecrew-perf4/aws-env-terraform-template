data "aws_caller_identity" "current" {}

####################################################################################
#cloudtrail
####################################################################################

resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt cloudteail"
}

resource "aws_kms_alias" "alias" {
  name          = "alias/${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail-key"
  target_key_id = "${aws_kms_key.mykey.key_id}"
}

resource "aws_cloudtrail" "mycloudtrail" {

  name                           = "${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail"
  s3_bucket_name                 = aws_s3_bucket.mybucket.id
  include_global_service_events  = true
  enable_log_file_validation     = true
  is_multi_region_trail          = true
  
  cloud_watch_logs_role_arn      = aws_iam_role.cwlog.arn
  cloud_watch_logs_group_arn     = "${aws_cloudwatch_log_group.cwlog.arn}:*"
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true

  }

  #kms_key_id                  = aws_kms_key.mykey.arn
  #tags                        = "var.resource_tag"
}

####################################################################################
#S3
####################################################################################
resource "aws_kms_key" "mykey2" {
  description             = "This key is used to encrypt cloudteail bucket objects"
}

resource "aws_kms_alias" "alias2" {
  name          = "alias/${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail-s3-key"
  target_key_id = "${aws_kms_key.mykey2.key_id}"
}


resource "aws_s3_bucket" "mybucket" {
  bucket = "${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail-log"
  acl    = "private"
  force_destroy = true
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.mykey2.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail-log"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail-log/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY  

}

resource "aws_s3_bucket_public_access_block" "mybucket" {
  bucket = "${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail-log"

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

####################################################################################
#cloudwatch log
####################################################################################
resource "aws_cloudwatch_log_group" "cwlog" {
  name = "${var.company_name}-${data.aws_caller_identity.current.account_id}-cloudtrail"
}

resource "aws_iam_role" "cwlog" {
  name = "cloudtrail-to-cloudwatch"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cwlog" {
  name = "cloudtrail-example"
  role = "${aws_iam_role.cwlog.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailCreateLogStream",
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream"],
      "Resource": [
        "arn:aws:logs:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.cwlog.id}:log-stream:*"
      ]
    },
    {
      "Sid": "AWSCloudTrailPutLogEvents",
      "Effect": "Allow",
      "Action": ["logs:PutLogEvents"],
      "Resource": [
        "arn:aws:logs:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.cwlog.id}:log-stream:*"
      ]
    }
  ]
}
EOF
}


