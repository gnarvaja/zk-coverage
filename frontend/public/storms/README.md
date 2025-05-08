# Storms

This directory was generated with the scripts in the `hurdat2` directory. In the future it would be good to 
leave these files out of the repository and generate them in a GitHub Workflow or something like that.

For each storm we have:
- <STORM_ID>.html: a HTML map with the affected areas and the hurricane path
- <STORM_ID>.json: a JSON file with the affected areas and all the information of the storm.
- <STORM_ID>-sign: a JSON file with the merkle root, the valid dates and the signature of all that information by
                   an authorized account. (TO DO)
