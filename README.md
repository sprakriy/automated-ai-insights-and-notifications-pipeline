# automated-ai-insights-and-notifications-pipeline

# Event-Driven Serverless AI Insights & Notifications Pipeline
A production-grade, fully automated AWS infrastructure pipeline built entirely with Terraform. This system detects document uploads to an Amazon S3 bucket, triggers a serverless AWS Lambda function to extract text contents, orchestrates a generative AI summarization task via Amazon Bedrock (Anthropic Claude 4 Sonnet), and broadcasts a structured executive summary to an Amazon SNS topic subscription list.

## System Architecture
The infrastructure follows an asynchronous, event-driven serverless pattern engineered for maximum throughput and zero idle costs:

1. **Storage Layer**: Amazon S3 bucket captures unstructured document uploads (`.txt`).
2. **Compute Layer**: AWS Lambda (Python 3.9) processes the asynchronous S3 Object Created notification event payload.
3. **AI Orchestration**: Lambda invokes an Amazon Bedrock Cross-Region Inference Profile to leverage Anthropic Claude 4 Sonnet for context-aware analysis.
4. **Notification Layer**: Generated insights are published to an Amazon SNS Topic, broadcasting immediately to email subscribers.

```mermaid
graph TD
    %% Define Visual Styles
    classDef tf fill:#5C4EE5,stroke:#333,stroke-width:2px,color:#fff;
    classDef aws fill:#FF9900,stroke:#333,stroke-width:2px,color:#000;
    classDef client fill:#333,stroke:#333,stroke-width:1px,color:#fff;

    %% Terraform Provisioning Layer
    subgraph TF [Infrastructure as Code Layer]
        T_Main[main.tf]
        T_IAM[iam.tf]
    end

    %% Active AWS Pipeline Execution Layer
    subgraph AWS [Serverless AWS Runtime Environment]
        subgraph Storage [Storage Layer]
            S3_Bucket[(S3 Upload Bucket)]
        end

        subgraph Compute [Compute & Security Layer]
            IAM_Role[Least-Privilege IAM Role]
            Lambda[AWS Lambda Engine]
        end

        subgraph AI [AI Orchestration Layer]
            Bedrock[Amazon Bedrock]
            Claude[Anthropic Claude 4 Sonnet]
        end

        subgraph Messaging [Notification Layer]
            SNS[SNS Topic]
        end
    end

    %% Build Connections & Logic Flow
    T_Main -.->|Deploys Resources| S3_Bucket & Lambda & Bedrock & SNS
    T_IAM -.->|Applies Granular Policies| IAM_Role
    IAM_Role ===>|Secures| Lambda

    User((User / System)) -->|1. Uploads .txt File| S3_Bucket
    S3_Bucket -->|2. s3:ObjectCreated Event| Lambda
    Lambda -->|3. InvokeModel with Payload| Bedrock
    Bedrock -->|4. Cross-Region Inference Profile| Claude
    Claude -->|5. Returns AI Insights| Lambda
    Lambda -->|6. sns:Publish Summary| SNS
    SNS -->|7. Email Broadcast| Subscribers((Subscribers Inbox))

    %% Apply Classes to Nodes
    class T_Main,T_IAM tf;
    class S3_Bucket,IAM_Role,Lambda,Bedrock,Claude,SNS aws;
    class User,Subscribers client;
```

---

## Technical Highlights & Guardrails
* **State Resilience**: Managed via a remote Amazon S3 backend at the root directory layer to ensure highly reliable state tracking and concurrent locking mechanisms.
* **Granular IAM Security Principle**: Bypasses loose wildcard execution policies. Implements strictly decoupled, least-privilege IAM policy attachments ensuring the Lambda role can only execute `s3:GetObject` on the targeted payload bucket, `sns:Publish` on the specific topic, and `bedrock:InvokeModel` on required global inference paths.
* **Cross-Region Inference Routing**: Optimized to run inside the highly stable `us-east-1` (N. Virginia) topology while dynamically consuming global inference models to bypass single-region concurrency throttles.
* **Zero Orphan Footprint**: Complete lifecycle predictability. Running a tear-down operation cleanly rolls back 100% of generated infrastructure components, leaving zero lingering resources or hidden billing cycles.

---

## Directory Structure
```text
automated-ai-insights-and-notifications-pipeline/
├── main.tf                 # Core infrastructure provider, S3 bucket, SNS topic, and Lambda configurations
├── iam.tf                  # Granular IAM roles, decoupled execution policies, and attachments
├── variables.tf            # Environment input variables (Regions, naming configurations)
├── outputs.tf              # Managed stack outputs (S3 bucket IDs, SNS Topic ARNs)
├── src/
│   └── lambda_function.py  # Python handler incorporating Anthropic payload specifications
└── test.txt                # Sample validation payload
```
