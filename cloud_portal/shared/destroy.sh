#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
# (but allow for the error trap)
set -eE

function report_err() {

  # post message slack channel (only if portal deployment)
  if [[ ! -n "$LOCAL_DEPLOYMENT" ]]; then

    curl -F text="Portal deployment failed" \
	     -F channels="portal-deploy-error" \
	     -F token="$SLACK_ERR_REPORT_TOKEN" \
	     https://slack.com/api/chat.postMessage

  fi
}


# Trap errors
trap 'report_err' ERR

# Destroy everything
cd "$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE"

ansible_inventory_file="$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE/inventory"

# read portal secrets from private repo
if [ -z "$LOCAL_DEPLOYMENT" ]; then
   source "$PORTAL_APP_REPO_FOLDER/phenomenal-cloudflare/cloudflare_token_phenomenal.cloud.sh"
   export SLACK_ERR_REPORT_TOKEN=$(cat "$PORTAL_APP_REPO_FOLDER/phenomenal-cloudflare/slacktoken")
fi

# TODO read this from deploy.sh file
export TF_VAR_boot_image="kubenow-v050b1"
export TF_VAR_kubeadm_token="fake.token"
export TF_VAR_master_disk_size="20"
export TF_VAR_node_disk_size="20"
export TF_VAR_edge_disk_size="20"
export TF_VAR_glusternode_disk_size="20"
export TF_VAR_ssh_key="$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE/vre.key.pub"

# workaround: -the credentials are provided as an environment variable, but KubeNow terraform scripts need a file.
if [ -n "$GOOGLE_CREDENTIALS" ]; then
  echo $GOOGLE_CREDENTIALS > "$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE/gce_credentials_file.json"
  export TF_VAR_gce_credentials_file="$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE/gce_credentials_file.json"
fi

# Add terraform to path (TODO) remove this portal workaround eventually
export PATH=/usr/lib/terraform_0.10.7:$PATH

KUBENOW_TERRAFORM_FOLDER="$PORTAL_APP_REPO_FOLDER/KubeNow/$PROVIDER"
terraform destroy --parallelism=50 --force --state="$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE/terraform.tfstate" "$KUBENOW_TERRAFORM_FOLDER"

# remove the gce workaround file if it is there
rm -f "$PORTAL_DEPLOYMENTS_ROOT/$PORTAL_DEPLOYMENT_REFERENCE/gce_credentials_file.json"
