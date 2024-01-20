# Building 🏗️

`docker build . -t rasterly_lambda:latest`

# Running 🏃

## Run the container with a bash shell

`docker run --env-file .env -it --entrypoint /bin/bash -v %cd%/src:/var/task rasterly_lambda:latest`

# Deploying 🚀

## Get the AWS ECR login password

`aws ecr get-login-password --region <region> --profile <profile> | docker login -u AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com`

## Tag the image

`docker tag rasterly_lambda:latest <aws_account_id>.dkr.ecr.<region>.amazonaws.com/rasterly_lambda:latest`

## Push the image

`docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/rasterly_lambda:latest`
