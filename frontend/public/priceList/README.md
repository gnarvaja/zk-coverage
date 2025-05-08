# Price Lists

This directory was generated with the scripts in the `hurdat2` directory. In the future it would be good to
leave these files out of the repository and generate them in a GitHub Workflow or something like that.

We have a single price list:

- pricelist.html: a HTML map with the loss probability for each area.
- pricelist.json: a JSON file with the loss probabilities for each area.
- pricelist.sig.json: a JSON file with the merkle root, the valid dates and the signature of all that information by
  an authorized account.

## Generation of signature files

```bash

# From zk-coverage repo root
export SIGNER_PK=...  # Secret private key
cd scripts/merkle
# install node dependencies
nvm use
npm install

PRICE_DIR=../../frontend/public/priceList/

# In reality, the validity dates should be taken from storm date. Valid From should be a few days AFTER the storm
# And VALID_TO should be 30 or 60 days after the storm
VALID_FROM=`date -d "30 days ago"  "+%s"`
VALID_TO=`date -d "+30 days"  "+%s"`

# Generate .sig.json files
node generate_signed_json $PRICE_DIR/pricelist.json $VALID_FROM $VALID_TO $PRICE_DIR/pricelist.sig.json
```
