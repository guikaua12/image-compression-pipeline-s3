interface Environment {
    BUCKET_NAME: string;
    AWS_REGION: string;
}

if(!process.env.BUCKET_NAME) {
    throw new Error("BUCKET_NAME environment variable missing.")
}

if(!process.env.AWS_REGION) {
    throw new Error("AWS_REGION environment variable missing.")
}

export const env: Environment = {
    BUCKET_NAME: process.env.BUCKET_NAME,
    AWS_REGION: process.env.AWS_REGION,
};