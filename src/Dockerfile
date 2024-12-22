FROM public.ecr.aws/lambda/python:3.13

# Copy the Lambda function code into the container
COPY hello.py ${LAMBDA_TASK_ROOT}/

# Copy the requirements.txt file
COPY requirement.txt ./

# Install the dependencies from requirements.txt
RUN pip install -r requirement.txt

# Set the Lambda handler
CMD ["hello.lambda_handler"]
