import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import {z, ZodError} from "zod";
import {env} from "./env"
import { v4 as uuidv4 } from 'uuid';

const s3Client = new S3Client({ region: env.aws_region || 'us-east-1' });

const uploadRequestSchema = z.object({
  fileName: z.string().max(255),
  fileType: z.literal([
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
  ])
})

type UploadRequest = z.infer<typeof uploadRequestSchema>

interface UploadResponse {
  uploadUrl: string;
  expiresIn: number;
}

async function generatePresignedUrl({fileName, fileType}: UploadRequest): Promise<UploadResponse> {
  const timestamp = Date.now();
  const normalizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
  const key = `${env.raw_bucket_prefix}/${timestamp}-${uuidv4()}-${normalizedFileName}`;

  const command = new PutObjectCommand({
    Bucket: env.bucket_name,
    Key: key,
    ContentType: fileType,
  });

  const expiresIn = 3600;

  const uploadUrl = await getSignedUrl(s3Client, command, {
    expiresIn
  });

  return {
    uploadUrl,
    expiresIn
  };
}

export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  console.log('Event:', JSON.stringify(event));
  console.log('Context:', JSON.stringify(context));

  const headers = {
    'Content-Type': 'application/json'
  };

  if(!event.body) {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({
        error: "Bad Request",
        message: "Missing body",
        requestId: context.awsRequestId,
      }),
    };
  }

  try {
    const body = uploadRequestSchema.parse(JSON.parse(event.body));

    const result = await generatePresignedUrl(body);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify(result),
    };

  } catch (error) {
    console.error('Error:', error);

    if(error instanceof ZodError) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: 'Bad Request',
          message: error.issues.map(issue => `${issue.path.join(", ")}: ${issue.message}`).join("; "),
          requestId: context.awsRequestId,
        }),
      };
    }

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
