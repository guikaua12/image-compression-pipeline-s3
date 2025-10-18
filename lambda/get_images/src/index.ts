import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import { DynamoDBClient, ScanCommand } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import { env } from "./env";

const dynamoDBClient = new DynamoDBClient({ region: env.aws_region });

export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  console.log('Event:', JSON.stringify(event));
  console.log('Context:', JSON.stringify(context));

  const headers = {
    'Content-Type': 'application/json'
  };

  try {
    const scanCommand = new ScanCommand({
      TableName: env.dynamodb_table_name
    });

    const result = await dynamoDBClient.send(scanCommand);

    const images = result.Items?.map(item => {
      const data = unmarshall(item);
      return {
        id: data.id,
        uploaded_at: data.uploaded_at,
        raw_image_url: `https://${env.cloudfront_domain_name}/${data.raw_object_key}`,
        compressed_image_url: `https://${env.cloudfront_domain_name}/${data.compressed_object_key}`
      };
    }) || [];

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ images }),
    };

  } catch (error) {
    console.error('Error:', error);

    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: 'Internal Server Error',
        message: error instanceof Error ? error.message : 'Unknown error',
        requestId: context.awsRequestId,
      }),
    };
  }
};
