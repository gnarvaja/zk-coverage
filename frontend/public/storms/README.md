# Storms

This directory was generated with the scripts in the `hurdat2` directory. In the future it would be good to
leave these files out of the repository and generate them in a GitHub Workflow or something like that.

For each storm we have:

- <STORM_ID>.html: a HTML map with the affected areas and the hurricane path
- <STORM_ID>.json: a JSON file with the affected areas and all the information of the storm.
- <STORM_ID>.sig.json: a JSON file with the merkle root, the valid dates and the signature of all that information by
  an authorized account.

## Generation of signature files

```bash

# From zk-coverage repo root
export SIGNER_PK=...  # Secret private key
cd scripts/merkle
# install node dependencies
nvm use
npm install

STORM_DIR=../../frontend/public/storms/

# In reality, the validity dates should be taken from storm date. Valid From should be a few days AFTER the storm
# And VALID_TO should be 30 or 60 days after the storm
VALID_FROM=`date -d "30 days ago"  "+%s"`
VALID_TO=`date -d "+30 days"  "+%s"`

# Generate .sig.json files
for STORM_ID in `find $STORM_DIR -name "AL??????.json" -exec basename -s .json  '{}' ';'` ; do
  node generate_signed_json $STORM_DIR/$STORM_ID.json $VALID_FROM $VALID_TO $STORM_DIR/$STORM_ID.sig.json
done
```
