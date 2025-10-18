# image-compression-pipeline-s3

![](/images/Image%20Compression%20Diagram%20AWS.drawio.png)

### Sobre o Projeto

Este projeto implementa um pipeline completa para o processamento e a distribuição de imagens na AWS.  
A proposta é oferecer uma estrutura estável, escalável e de fácil manutenção, capaz de receber imagens, comprimí-las automaticamente e disponibilizá-las por meio de uma CDN global.

O sistema utiliza URLs pré-assinadas para o upload das imagens, processa os arquivos de forma automática e distribui o conteúdo pelo CloudFront.  

---

### Como a Arquitetura Funciona

O funcionamento é todo baseado em eventos, conectando diversos serviços da AWS em um fluxo automatizado.  

1. O cliente solicita uma URL pré-assinada via API Gateway. Essa solicitação ativa uma função Lambda, responsável por gerar credenciais temporárias para o envio direto ao S3.
2. Assim que o upload é concluído, o S3 envia uma notificação para uma fila SQS, que aciona outra função Lambda dedicada à compressão da imagem.
3. Essa Lambda utiliza a biblioteca Sharp para comprimir as imagens e registra os metadados no DynamoDB.
4. Uma Lambda adicional permite listar todas as imagens já processadas, retornando URLs prontas para o acesso usando o CloudFront.

---

### Como rodar

#### **Pré-requisitos**
- AWS CLI configurado com credenciais válidas
- Terraform (versão compatível com AWS Provider v5+)
- Node.js 20+ e npm instalados

#### **Passos**

1. Clone o repositório e acesse o diretório do projeto:  
   ```bash
   git clone https://github.com/guikaua12/image-compression-pipeline-s3.git && cd image-compression-pipeline-s3
   ```

2. Vá até a pasta de infraestrutura:
   ```bash
   cd infra
   ```

3. Compile as funções Lambda:
   ```bash
   cd ../lambda/upload && npm install && npm run build:prod
   cd ../image_compression && npm install && npm run build:prod
   cd ../get_images && npm install && npm run build:prod
   ```

4. Aplique os recursos de infraestrutura usando Terraform:
   ```bash
   cd ../../infra
   terraform init
   terraform plan -var-file="variables/prod.tfvars"
   terraform apply -var-file="variables/prod.tfvars"
   ```

---

### Uso da API

Após a criação dos recursos, o Terraform exibirá as URLs do endpoint do API Gateway e do CloudFront.  
Esses endpoints permitem o envio, listagem e visualização de imagens processadas.

| Método | Endpoint                  | Descrição                                        |
|--------|---------------------------|--------------------------------------------------|
| POST   | `/images/upload/presign`  | Retorna uma URL pré-assinada para upload         |
| GET    | `/images`                 | Lista imagens processadas com URLs do CloudFront |

---

### Tecnologias Utilizadas

#### **Serviços AWS**
- **S3** – Armazenamento principal para imagens originais e otimizadas
- **Lambda** – Execução das funções de upload, compressão e listagem
- **API Gateway** – Interface REST para comunicação com os serviços
- **CloudFront** – CDN para entrega rápida de conteúdo
- **DynamoDB** – Banco de dados NoSQL para metadados
- **SQS** – Fila de mensagens para o processamento assíncrono

#### **Infraestrutura**
- **Terraform** – Provisionamento completo da infraestrutura AWS como código

#### **Desenvolvimento**
- **TypeScript** – Linguagem principal das funções Lambda
- **Sharp** – Biblioteca de processamento e compressão de imagens
- **AWS SDK v3** – Cliente modular para integração com os serviços AWS  