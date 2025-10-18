interface Environment {
    dynamodb_table_name: string;
    aws_region: string;
    cloudfront_domain_name: string;
}

const partialEnv: Partial<Environment> = {
    dynamodb_table_name: process.env.DYNAMODB_TABLE_NAME,
    aws_region: process.env.AWS_REGION,
    cloudfront_domain_name: process.env.CLOUDFRONT_DOMAIN_NAME,
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
