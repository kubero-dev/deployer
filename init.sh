#!/usr/bin/env bash

# check if all required variables are set
if [ -z "$NAME" ] || [ -z "$APP" ] || [ -z "$PHASE" ] || [ -z "$PIPELINE" ] || [ -z "$REPOSITORY" ] || [ -z "$TAG" ] || [ -z "$SERVICE_ACCOUNT" ] || [ -z "$BUILDER" ] || [ -z "$URL" ] || [ -z "$REVISION" ]; then
  echo "One or more required variables are not set"
  exit 1
fi

kubectl apply -f - <<EOF
apiVersion: kpack.io/v1alpha2
kind: Build
metadata:
  name: ${NAME}
spec:
  tags:
  - ${REPOSITORY}:${TAG}
  serviceAccountName: ${SERVICE_ACCOUNT}
  builder:
    image: ${BUILDER}
  source:
    git:
      url: ${URL}
      revision: ${REVISION}
EOF

# check if kubectl command failed
if [ $? -ne 0 ]; then
  echo "Failed to create build pod"
  exit 1
fi

sleep 2

## check with kubectl if the pod is completed
while true; do
  PHASE=$(kubectl get pod ${NAME}-build-pod -o jsonpath='{.status.phase}')
  if [ "$PHASE" == "Succeeded" ]; then
    echo "Build completed successfully"
    break
  fi
  if [ "$PHASE" == "Failed" ]; then
    echo "Build failed"
    break
  fi
  echo "Waiting for build to complete...$PHASE"
  sleep 1
done

sleep 2

# patch kuberoes resource with the new image
kubectl patch --type=merge kuberoapps.application.kubero.dev ${APP} -p "{\"spec\":{\"image\":{\"repository\":\"${REPOSITORY}\",\"tag\":\"${TAG}\"}}}"
if [ $? -ne 0 ]; then
  echo "Failed to patch kubero app resource"
  exit 1
fi

exit 0