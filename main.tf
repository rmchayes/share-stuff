provider "aws" {
  region = "us-east-1"
}

resource "aws_api_gateway_rest_api" "MyAPI" {
  name        = "xxx"
  description = "API Gateway for Lambda integration"
}

resource "aws_lambda_function" "MyLambda" {
  function_name    = "MyLambdaFunction"
  handler          = "lambda.handler"
  role             = aws_iam_role.lambda_exec_role.arn
  runtime          = "nodejs20.x"
  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      EXAMPLE_VARIABLE = "example_value"
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_api_gateway_resource" "MyResource" {
  rest_api_id = aws_api_gateway_rest_api.MyAPI.id
  parent_id   = aws_api_gateway_rest_api.MyAPI.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "MyMethod" {
  rest_api_id   = aws_api_gateway_rest_api.MyAPI.id
  resource_id   = aws_api_gateway_resource.MyResource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "LambdaIntegration" {
  rest_api_id = aws_api_gateway_rest_api.MyAPI.id
  resource_id = aws_api_gateway_resource.MyResource.id
  http_method = aws_api_gateway_method.MyMethod.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.MyLambda.invoke_arn
}


// CORS MADNESS
resource "aws_api_gateway_method" "CorsOptions" {
  rest_api_id   = aws_api_gateway_rest_api.MyAPI.id
  resource_id   = aws_api_gateway_resource.MyResource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "CorsOptionsResponse200" {
  depends_on  = [aws_api_gateway_method.CorsOptions]
  rest_api_id = aws_api_gateway_rest_api.MyAPI.id
  resource_id = aws_api_gateway_resource.MyResource.id
  http_method = aws_api_gateway_method.CorsOptions.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true,
  }
}

resource "aws_api_gateway_integration_response" "CorsOptionsIntegrationResponse" {
  depends_on  = [aws_api_gateway_method_response.CorsOptionsResponse200]
  rest_api_id = aws_api_gateway_rest_api.MyAPI.id
  resource_id = aws_api_gateway_resource.MyResource.id
  http_method = aws_api_gateway_method.CorsOptions.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'" # Adjust this value for production environments
  }

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_integration" "CorsOptionsIntegration" {
  depends_on  = [aws_api_gateway_method.CorsOptions]
  rest_api_id = aws_api_gateway_rest_api.MyAPI.id
  resource_id = aws_api_gateway_resource.MyResource.id
  http_method = aws_api_gateway_method.CorsOptions.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

// CORS MADNESS ENDS

resource "aws_lambda_permission" "AllowAPIGatewayInvoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.MyLambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.MyAPI.execution_arn}/*/*/*"
}

resource "aws_api_gateway_deployment" "MyDeployment" {
  depends_on = [
    aws_api_gateway_integration.LambdaIntegration,
    aws_api_gateway_integration.CorsOptionsIntegration,
  ]

  rest_api_id = aws_api_gateway_rest_api.MyAPI.id
  stage_name  = "test"

  # Adjust the triggers block to include the Lambda function's source code hash
  triggers = {
    redeployment = sha1(jsonencode({
      integration = aws_api_gateway_integration.LambdaIntegration.id,
      options     = aws_api_gateway_integration.CorsOptionsIntegration.id,
      lambda_code_hash = aws_lambda_function.MyLambda.source_code_hash, # Include this line
    }))
  }
}
