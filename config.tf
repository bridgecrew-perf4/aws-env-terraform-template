data "aws_caller_identity" "current2" {}

####################################################################################
#config Role
####################################################################################

resource "aws_iam_role" "my-config" {
  name = "${var.company_name}_${data.aws_caller_identity.current2.account_id}_config_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "my-config" {
  role       = "${aws_iam_role.my-config.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

####################################################################################
#S3
####################################################################################

resource "aws_kms_key" "my-config" {
  description             = "This key is used to encrypt config bucket objects"
}

resource "aws_kms_alias" "alias3" {
  name          = "alias/${var.company_name}-${data.aws_caller_identity.current2.account_id}-config-s3-key"
  target_key_id = "${aws_kms_key.my-config.key_id}"
}


resource "aws_s3_bucket" "my-config" {
  bucket = "${var.company_name}-${data.aws_caller_identity.current2.account_id}-config-log"
  acl    = "private"
  force_destroy = true
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.my-config.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSConfigBucketPermissionsCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "config.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.company_name}-${data.aws_caller_identity.current2.account_id}-config-log"
        },
        {
            "Sid": "AWSConfigBucketDelivery",
            "Effect": "Allow",
            "Principal": {
                "Service": "config.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.company_name}-${data.aws_caller_identity.current2.account_id}-config-log/AWSLogs/${data.aws_caller_identity.current2.account_id}/Config/*",
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

####################################################################################
#config
####################################################################################
resource "aws_config_configuration_recorder" "my-config" {
  name     = "${var.company_name}-${data.aws_caller_identity.current2.account_id}-config"
  role_arn = "${aws_iam_role.my-config.arn}"

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "my-config" {
  name           = "${var.company_name}-${data.aws_caller_identity.current2.account_id}-config"
  s3_bucket_name = "${aws_s3_bucket.my-config.bucket}"

  depends_on = ["aws_config_configuration_recorder.my-config"]
}

resource "aws_config_configuration_recorder_status" "config" {
  name       = "${aws_config_configuration_recorder.my-config.name}"
  is_enabled = true

  depends_on = ["aws_config_delivery_channel.my-config"]
}