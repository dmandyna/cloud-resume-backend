resource "aws_dynamodb_table" "counter" {
  name           = "visitors_counter"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "site"

  attribute {
    name = "site"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "this" {
  table_name = aws_dynamodb_table.counter.name
  hash_key   = aws_dynamodb_table.counter.hash_key
  item       = <<ITEM
  {
    "${aws_dynamodb_table.counter.hash_key}": {"S": "cloud_resume"},
    "count": {"N": "0"}
  }
  ITEM

  lifecycle {
    ignore_changes = [
      item
    ]
  }
}

resource "aws_dynamodb_table" "tracker" {
  name           = "visitors_tracker"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "ip_address"

  attribute {
    name = "ip_address"
    type = "S"
  }

  ttl {
    attribute_name = "expiry_date"
    enabled        = true
  }
}
