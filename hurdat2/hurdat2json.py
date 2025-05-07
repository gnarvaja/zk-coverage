import csv
import sys
import json
import datetime
import zoneinfo

UTC = zoneinfo.ZoneInfo("UTC")


def parse_record_type(record_type):
    record_type = record_type.strip()
    record_description = {
        "": None,
        "L": "Landfall",
        "C": "Closest approach to a coast, not followed by a landfall",
        "G": "Genesis",
        "I": "An intensity peak in terms of both pressure and wind",
        "P": "Minimum in central pressure",
        "R": "Provides additional detail on the intensity of the cyclone when rapid changes are underway",
        "S": "Change of status of the system",
        "T": "Provides additional detail on the track (position) of the cyclone",
        "W": "Maximum sustained wind speed",
    }[record_type]
    return {"type": record_type, "description": record_description}


def parse_system_status(system_status):
    system_status = system_status.strip()
    description = {
        "TD": "Tropical cyclone of tropical depression intensity (< 34 knots)",
        "TS": "Tropical cyclone of tropical storm intensity (34-63 knots)",
        "HU": "Tropical cyclone of hurricane intensity (> 64 knots)",
        "EX": "Extratropical cyclone (of any intensity)",
        "SD": "Subtropical cyclone of subtropical depression intensity (< 34 knots)",
        "SS": "Subtropical cyclone of subtropical storm intensity (> 34 knots)",
        "LO": "A low that is neither a tropical cyclone, a subtropical cyclone, nor an extratropical cyclone (of any intensity)",
        "WV": "Tropical Wave (of any intensity)",
        "DB": "Disturbance (of any intensity)",
    }[system_status]
    return {"status": system_status, "description": description}


def parse_lat(lat_str):
    lat = float(lat_str[:-1])
    if lat_str[-1].upper() == "S":
        return -lat
    return lat


def parse_lng(lon_str):
    lon = float(lon_str[:-1])
    if lon_str[-1].upper() == "W":
        return -lon
    return lon


def hurdat2_to_json(hurdat2_filename, output_pattern):
    """Processes a Hurdat2 file and generates json files for each storm, organized by years"""
    hurdat2 = csv.reader(open(hurdat2_filename))

    while True:
        try:
            row = next(hurdat2)
        except StopIteration:
            break
        record_count = int(row[2])
        storm = parse_storm([row] + [next(hurdat2) for _ in range(record_count)])
        json.dump(storm, open(output_pattern.format(year=storm["year"], storm_id=storm["id"]), "w"), indent=2)


def read_storm(hurdat2_filename, storm_id):
    """Reads the data of a specific storm from a HURDAT2 file"""
    hurdat2 = csv.reader(open(hurdat2_filename))

    while True:
        try:
            row = next(hurdat2)
        except StopIteration:
            break
        record_count = int(row[2])
        if storm_id != row[0]:
            # skip the records
            [next(hurdat2) for _ in range(record_count)]
        else:
            return parse_storm([row] + [next(hurdat2) for _ in range(record_count)])


def parse_storm(rows):
    """Parses a set of rows of a HURDAT2 file where the first one is the header"""
    row = rows[0]
    assert len(row) == 4, "Not a header row"

    storm_id = row[0]
    year = storm_id[-4:]
    storm_name = row[1].strip()
    storm = dict(year=int(year), id=storm_id, name=storm_name, record_count=int(row[2]), records=[])
    for row in rows[1:]:
        record = dict(
            date_time=datetime.datetime.strptime(f"{row[0]} {row[1]}", "%Y%m%d %H%M").replace(tzinfo=UTC).isoformat(),
            record_type=parse_record_type(row[2]),
            system_status=parse_system_status(row[3]),
            lat=parse_lat(row[4]),
            lng=parse_lng(row[5]),
            max_sustained_wind=int(row[6]),
            min_pressure=int(row[7]),
            ne_34kt_wind_radii=int(row[8]),
            se_34kt_wind_radii=int(row[9]),
            nw_34kt_wind_radii=int(row[10]),
            sw_34kt_wind_radii=int(row[11]),
            ne_50kt_wind_radii=int(row[12]),
            se_50kt_wind_radii=int(row[13]),
            nw_50kt_wind_radii=int(row[14]),
            sw_50kt_wind_radii=int(row[15]),
            ne_64kt_wind_radii=int(row[16]),
            se_64kt_wind_radii=int(row[17]),
            nw_64kt_wind_radii=int(row[18]),
            sw_64kt_wind_radii=int(row[19]),
            max_wind_radius=int(row[20]),
        )
        storm["records"].append(record)
    return storm


if __name__ == "__main__":
    hurdat2_to_json(sys.argv[1], sys.argv[2])
