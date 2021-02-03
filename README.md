# aiven-infra
This repo is intended testing the deployment of a Kafka-Elasticsearch-InfluxDB-Grafana data pipeline on the Aiven platform. The PDF describes the architecture and features of the infrastructure, and how it could be further developed.

## How to use
1. Clone the repo and run `terraform init`.
2. Set the environment variables `TF_VAR_aiven_api_token` and `TF_VAR_aiven_project_name` or insert the corresponding values to `terraform.tfvars`. Unless you're using a trial account or something similar, you'll likely also need to include your billing information in the project resource.
3. Run `terraform apply` to deploy the infrastructure into your Aiven account.

## Test the pipeline with Kafka, Grafana, and ES

Everything is deployed to a VPC for securiry reasons, so you cannot access the services right away. To test the data pipeline works as intended, let's expose a few services to public internet so we can easily access them.

1. In the Aiven console, go to **Services** and enable the following features in the **Advanced configuration** section of the services listed below:
* `exercise-grafana`: `public_access.grafana`
* `exercise-kf`: `public_access.kafka_rest`
* `exercise-es`: `kibana.enabled` and `public_access.kibana`

2. In terminal, produce a few messages with `curl` or some other way. Replace `<PASSWORD-HERE>` and `<PROJECT-HERE>` with your credentials.
`curl -X POST -H "Content-Type: application/vnd.kafka.json.v1+json" --data "{\"records\":[{\"key\":"1", \"value\":{\"hey-hey\":\"my,my\"}}]}" "https://avnadmin:<PASSWORD-HERE>@public-exercise-kf-<PROJECT-HERE>.aivencloud.com:18607/topics/ingest_example"`

3. Open Grafana from the **Service URI** link in your `exercise-grafana` service while you have **Access Route** set to **Public**.

4. After logging in, click the magnifying glass and you should see `Aiven Elasticsearch - exercise-es - Resources` and `Aiven Kafka - exercise-kf - Resources`. Open the Kafka one. You should see recent changes in **Inbound messages**.

5. In Aiven Console, open the **Kibana** tab of `exercise-es`.

6. With the **Access Route** switched to **Public**, open the **Service URI** link.

7. Log in and open **Dev Tools** in the hamburger menu.

8. Run e.g. `GET /ingest_example/_search`. You should see something like this:

```
      {
        "_index" : "ingest_example",
        "_type" : "es-connector",
        "_id" : "ingest_example+1+7",
        "_score" : 1.0,
        "_source" : {
          "hey-hey" : "my,my"
        }
      },
```
