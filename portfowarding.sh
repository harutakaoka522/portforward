#!/bin/bash

# 利用可能なAWSプロファイルのリストを表示
echo "利用可能なAWSプロファイル:"
aws configure list-profiles

# AWSプロファイル名の入力を求める
read -p "利用するAWSプロファイル名を入力してください: " AWS_PROFILE

# AWSリージョンを指定
AWS_REGION="ap-northeast-1"

# EC2インスタンス名のリストを取得
echo "利用可能なEC2インスタンス (起動中):"
aws ec2 describe-instances --profile ${AWS_PROFILE} --region ${AWS_REGION} --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' --output text

# ユーザーにEC2インスタンス名を選択させる
read -p "利用するEC2インスタンス名を入力してください: " INSTANCE_NAME

# RDSがクラスターかインスタンスかを質問
read -p "RDSはクラスターですか？(yes/no): " IS_CLUSTER

if [ "$IS_CLUSTER" == "yes" ]; then
  # RDSクラスター名のリストを取得
  echo "利用可能なRDSクラスター:"
  aws rds describe-db-clusters --profile ${AWS_PROFILE} --region ${AWS_REGION} --query 'DBClusters[*].DBClusterIdentifier' --output text

  # ユーザーにRDSクラスター名を選択させる
  read -p "利用するRDSクラスター名を入力してください: " RDS_CLUSTER_IDENTIFIER

  # RDSクラスターエンドポイントを取得
  RDS_ENDPOINT=$(aws rds describe-db-clusters --profile ${AWS_PROFILE} --region ${AWS_REGION} --db-cluster-identifier ${RDS_CLUSTER_IDENTIFIER} --query "DBClusters[0].Endpoint" --output text)

  # RDSエンドポイントが取得できなかった場合の処理
  if [ -z "$RDS_ENDPOINT" ]; then
    echo "RDSエンドポイントが取得できませんでした。RDSクラスター識別子を確認してください。"
    exit 1
  fi
else
  # RDSインスタンス名のリストを取得
  echo "利用可能なRDSインスタンス:"
  aws rds describe-db-instances --profile ${AWS_PROFILE} --region ${AWS_REGION} --query 'DBInstances[*].DBInstanceIdentifier' --output text

  # ユーザーにRDSインスタンス名を選択させる
  read -p "利用するRDSインスタンス名を入力してください: " RDS_INSTANCE_IDENTIFIER

  # RDSインスタンスエンドポイントを取得
  RDS_ENDPOINT=$(aws rds describe-db-instances --profile ${AWS_PROFILE} --region ${AWS_REGION} --db-instance-identifier ${RDS_INSTANCE_IDENTIFIER} --query "DBInstances[0].Endpoint.Address" --output text)

  # RDSエンドポイントが取得できなかった場合の処理
  if [ -z "$RDS_ENDPOINT" ]; then
    echo "RDSエンドポイントが取得できませんでした。RDSインスタンス名を確認してください。"
    exit 1
  fi
fi

# インスタンスIDを取得
INSTANCE_ID=$(aws ec2 describe-instances --profile ${AWS_PROFILE} --region ${AWS_REGION} --filters "Name=tag:Name,Values=${INSTANCE_NAME}" --query "Reservations[*].Instances[*].InstanceId" --output text)

# インスタンスIDが取得できなかった場合の処理
if [ -z "$INSTANCE_ID" ]; then
  echo "インスタンスIDが取得できませんでした。インスタンス名を確認してください。"
  exit 1
fi

# ポートフォワーディングセッションの開始
aws ssm start-session --profile ${AWS_PROFILE} --region ${AWS_REGION} \
    --target ${INSTANCE_ID} \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"${RDS_ENDPOINT}\"],\"portNumber\":[\"3306\"], \"localPortNumber\":[\"3306\"]}"
