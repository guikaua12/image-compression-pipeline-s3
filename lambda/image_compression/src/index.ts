import {S3Event, S3EventRecord, SQSBatchItemFailure, SQSBatchResponse, SQSEvent} from 'aws-lambda';
import {S3Client, PutObjectCommand, GetObjectCommand} from '@aws-sdk/client-s3';
import {DynamoDBClient, PutItemCommand} from '@aws-sdk/client-dynamodb';
import {env} from "./env"
import sharp from "sharp";
import {v4 as uuidv4} from 'uuid';

const s3Client = new S3Client({ region: env.aws_region });
const dynamoDBClient = new DynamoDBClient({ region: env.aws_region });

const processS3EventRecord = async (record: S3EventRecord) => {
  const bucket = record.s3.bucket.name;
  const key = decodeURIComponent(record.s3.object.key);
  const newKey = key.replace(env.raw_bucket_prefix, env.compressed_bucket_prefix);

  const command = new GetObjectCommand({
    Bucket: bucket,
    Key: key
  });

  const originalImage = await s3Client.send(command);

  const id = originalImage.Metadata?.id || uuidv4();
  const uploadedAt = originalImage.LastModified?.toISOString() || new Date().toISOString();

  const compressedBuffer = await sharp(await originalImage.Body?.transformToByteArray())
      .jpeg({ quality: 30 })
      .toBuffer();

  const putCommand = new PutObjectCommand({
    Bucket: bucket,
    Key: newKey,
    Body: compressedBuffer,
    ContentType: "image/jpeg"
  });

  await s3Client.send(putCommand);

  const putItemCommand = new PutItemCommand({
    TableName: env.dynamodb_table_name,
    Item: {
      id: { S: id },
      uploaded_at: { S: uploadedAt },
      raw_object_key: { S: key },
      compressed_object_key: { S: newKey }
    }
  });

  await dynamoDBClient.send(putItemCommand);
}

export const handler = async (
  event: SQSEvent
): Promise<SQSBatchResponse> => {
  console.log('Event:', JSON.stringify(event));

  const batchItemFailures: SQSBatchItemFailure[] = [];

  await Promise.allSettled(
      event.Records.map(async (record) => {
        try {
          const s3Event: S3Event = JSON.parse(record.body);

          for (let s3EventRecord of s3Event.Records) {
            await processS3EventRecord(s3EventRecord);
          }

        } catch (error) {
          console.error('Error:', error);

          batchItemFailures.push({
            itemIdentifier: record.messageId
          });
        }
      })
  )


  return { batchItemFailures };
};
