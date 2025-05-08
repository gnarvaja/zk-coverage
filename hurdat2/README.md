# Hurricane information (HURDAT2) processing

In this folder we have the Python scripts to process the Hurdat2 information, to compute the affected areas of a storm
and to compute the price list that comes from the risk analysis of each region.

## 1. Download Hurdat2 database

Go to https://www.nhc.noaa.gov/data/#hurdat and download the latest hurricane database

```bash
wget https://www.nhc.noaa.gov/data/hurdat/hurdat2-1851-2024-040425.txt
```

## 2. Install Python dependencies

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 3. Generate affected areas maps

```bash
HURDAT2_FILE=./hurdat2-1851-2024-040425.txt
DISTANCE=50
RESOLUTION=6
WIND_SPEED=64
OUTPUT_DIR=hurdat2/outputs
# Storms since 2020
STORMS=`egrep "^AL[0-9][0-9]202[0-4].*" hurdat2-1851-2024-040425.txt | cut -f1 -d,`

for STORM_ID in $STORMS; do
  python3 -m hurdat2.compute_affected_cells --hurdat2 $HURDAT2_FILE \
    --resolution $RESOLUTION --radius $DISTANCE --min-wind $WIND_SPEED \
    affected_areas --storm $STORM_ID \
                   --map-output $OUTPUT_DIR/${STORM_ID}.html \
                   --json-output $OUTPUT_DIR/${STORM_ID}.json
done

python3 -m http.server -d $OUTPUT_DIR
```

## 4. Generate the price list

```bash
HURDAT2_FILE=./hurdat2-1851-2024-040425.txt
DISTANCE=50
RESOLUTION=3
WIND_SPEED=64
OUTPUT_DIR=hurdat2/outputs

python3 -m hurdat2.compute_affected_cells --hurdat2 $HURDAT2_FILE \
  --resolution $RESOLUTION --radius $DISTANCE --min-wind $WIND_SPEED \
  price_list --year-from 1924 --year-to 2023 \
             --map-output $OUTPUT_DIR/pricelist.html \
             --json-output $OUTPUT_DIR/pricelist.json

python3 -m http.server -d $OUTPUT_DIR
```
