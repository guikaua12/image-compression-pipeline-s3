interface Environment {
    raw_bucket_prefix: string;
    compressed_bucket_prefix: string;
    aws_region: string;
    dynamodb_table_name: string;
}

const partialEnv: Partial<Environment> = {
    raw_bucket_prefix: process.env.RAW_BUCKET_PREFIX,
    compressed_bucket_prefix: process.env.COMPRESSED_BUCKET_PREFIX,
    aws_region: process.env.AWS_REGION,
    dynamodb_table_name: process.env.DYNAMODB_TABLE_NAME,
};


const validateVariables = (variables: Partial<Environment>) => {
    const missingVariables = Object.entries(variables)
        .filter(([_, value]) => !value)
        .map(([key]) => key);

    if(missingVariables.length > 0) {
        throw new Error(`Environment variables missing (${missingVariables.join(", ")}).`)
    }
};

validateVariables(partialEnv);

export const env = partialEnv as Environment;