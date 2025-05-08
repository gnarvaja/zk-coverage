import sys
import argparse
import h3
import numpy as np
import logging
import folium
from branca.colormap import linear
import numpy as np
from functools import partial
from itertools import groupby

from . import hurdat2json

logger = logging.getLogger(__name__)

# Edge length in KM
EDGE_LENGTH = {
    0: 1281.256011,
    1: 483.0568391,
    2: 182.5129565,
    3: 68.97922179,
    4: 26.07175968,
    5: 9.854090990,
    6: 3.724532667,
    7: 1.406475763,
    8: 0.531414010,
    9: 0.200786148,
    10: 0.075863783,
}

MAX_SEVERITY = 5

# US as resolution 2 hexagons - Copied from https://observablehq.com/@nrabinowitz/h3-cell-counts-per-country
us_hexagons = [
    "822b8ffffffffff",
    "822617fffffffff",
    "82288ffffffffff",
    "8248d7fffffffff",
    "8226f7fffffffff",
    "8244c7fffffffff",
    "82266ffffffffff",
    "822ad7fffffffff",
    "82274ffffffffff",
    "8226c7fffffffff",
    "8228b7fffffffff",
    "822aa7fffffffff",
    "82271ffffffffff",
    "8244effffffffff",
    "822997fffffffff",
    "822697fffffffff",
    "82260ffffffffff",
    "822887fffffffff",
    "8248cffffffffff",
    "822777fffffffff",
    "8226effffffffff",
    "822667fffffffff",
    "82489ffffffffff",
    "822747fffffffff",
    "822637fffffffff",
    "8228affffffffff",
    "822a9ffffffffff",
    "82279ffffffffff",
    "822a17fffffffff",
    "8244e7fffffffff",
    "82298ffffffffff",
    "82268ffffffffff",
    "82445ffffffffff",
    "822607fffffffff",
    "8248c7fffffffff",
    "82276ffffffffff",
    "8226e7fffffffff",
    "82265ffffffffff",
    "8228d7fffffffff",
    "8229b7fffffffff",
    "8226b7fffffffff",
    "82262ffffffffff",
    "8228a7fffffffff",
    "822b1ffffffffff",
    "8248effffffffff",
    "82281ffffffffff",
    "822a97fffffffff",
    "822797fffffffff",
    "82270ffffffffff",
    "8244dffffffffff",
    "822987fffffffff",
    "822687fffffffff",
    "824457fffffffff",
    "8226dffffffffff",
    "8244affffffffff",
    "822657fffffffff",
    "82488ffffffffff",
    "8229affffffffff",
    "8226affffffffff",
    "822627fffffffff",
    "82289ffffffffff",
    "822817fffffffff",
    "822a8ffffffffff",
    "82278ffffffffff",
    "8228f7fffffffff",
    "82444ffffffffff",
    "82275ffffffffff",
    "8226d7fffffffff",
    "82264ffffffffff",
    "824887fffffffff",
    "8229a7fffffffff",
    "8226a7fffffffff",
    "82261ffffffffff",
    "822897fffffffff",
    "8248dffffffffff",
    "822a87fffffffff",
    "822787fffffffff",
    "8244cffffffffff",
    "822677fffffffff",
    "824447fffffffff",
    "822757fffffffff",
    "8226cffffffffff",
    "822647fffffffff",
    "8212dffffffffff",
    "822837fffffffff",
    "822aaffffffffff",
    "8227affffffffff",
    "8244f7fffffffff",
    "82299ffffffffff",
    "82269ffffffffff",
    "82446ffffffffff",
    "825d17fffffffff",
    "820c0ffffffffff",
    "820d57fffffffff",
    "820c77fffffffff",
    "820c27fffffffff",
    "820d47fffffffff",
    "820d1ffffffffff",
    "820c67fffffffff",
    "820d5ffffffffff",
    "820d0ffffffffff",
    "820c57fffffffff",
    "820ce7fffffffff",
    "820c2ffffffffff",
    "820d77fffffffff",
    "820c07fffffffff",
    "820c6ffffffffff",
    "820c1ffffffffff",
]

us_hexagons_extended = set()

for hexa in us_hexagons:
    us_hexagons_extended.add(hexa)
    us_hexagons_extended.update(h3.grid_ring(hexa, k=1))


def epicenter_areas_affected(lat, lng, radius_km, resolution, severity_function):
    """
    Finds the affected areas of a given resultion within a given radium

    Returns a dictionary of <h3index>=>distance * severity_factor
    """
    origin = h3.latlng_to_cell(lat, lng, resolution)
    edge_length_km = EDGE_LENGTH[resolution]
    k = int(np.ceil(radius_km / edge_length_km))

    result = {}
    for r in range(0, k + 1):
        if r == 0:
            ring = {origin}
        else:
            ring = h3.grid_ring(origin, r)

        for hexagon in ring:
            if hexagon in result:
                continue
            hex_center = h3.cell_to_latlng(hexagon)
            distance = h3.great_circle_distance((lat, lng), hex_center, unit="km")
            if distance <= (radius_km + edge_length_km):
                result[hexagon] = severity_function(distance=distance)

    return result


def severity_function_range5(radius_km, resolution, min_wind, distance, wind):
    """Function that computes the severity as a value between 1 and 5 - Used for affected areas"""
    edge_length_km = EDGE_LENGTH[resolution]
    distance_factor = MAX_SEVERITY - round(
        distance / ((radius_km + edge_length_km) / (MAX_SEVERITY - 1))
    )  # 1..10
    assert distance_factor > 0 and distance_factor <= MAX_SEVERITY
    wind_factor = {1: 1, 2: 1.5, 3: 2}[min(round(wind / min_wind), 3)]
    return min(round(distance_factor * wind_factor), MAX_SEVERITY)


def is_in_us(lat, lng):
    h3_level2 = h3.latlng_to_cell(lat, lng, 2)
    if h3_level2 not in us_hexagons_extended:
        return False
    if h3_level2 in us_hexagons:
        return True
    # Compute the distance to the closest us_hexagons
    min_distance = min(
        [
            h3.great_circle_distance((lat, lng), h3.cell_to_latlng(us_hexa), unit="km")
            for us_hexa in h3.grid_ring(h3_level2, k=1)
            if us_hexa in us_hexagons
        ]
    )
    if min_distance <= EDGE_LENGTH[2] * 2:
        return True
    return False


def _merge_into(existing, new, merge_fn):
    """Merges two dictionaries using merge_fn for the values"""
    # Add the new found indexes or the ones that have greater severity
    for key, value in new.items():
        if key not in existing:
            existing[key] = value
        else:
            existing[key] = merge_fn(existing[key], value)


def find_impacted_indexes(
    storm_data,
    radius_km,
    resolution,
    min_wind,
    severity_function=severity_function_range5,
):
    impacted_h3_indexes = {}
    for record in storm_data["records"]:
        wind = record["max_sustained_wind"]
        if wind < min_wind:
            continue
        lat, lng = record["lat"], record["lng"]
        if not is_in_us(lat, lng):
            continue  # Skip because not in US
        severity_fn = partial(
            severity_function,
            radius_km=radius_km,
            resolution=resolution,
            min_wind=min_wind,
            wind=wind,
        )
        h3_indexes = epicenter_areas_affected(
            record["lat"], record["lng"], radius_km, resolution, severity_fn
        )
        logger.debug(f"{len(h3_indexes)} found for {record}")

        # Add the new found indexes or the ones that have greater severity
        _merge_into(impacted_h3_indexes, h3_indexes, lambda a, b: a if a > b else b)

    logger.debug(f"Total Indexes: {len(impacted_h3_indexes)}")
    return impacted_h3_indexes


def compute_price_list(hurdat2_filename, years, find_indexes_fn):
    commulative_severity = {}
    for storm in hurdat2json.read_storms(hurdat2_filename, years):
        h3_indexes = find_indexes_fn(storm_data=storm)
        _merge_into(commulative_severity, h3_indexes, lambda a, b: a + b)
    return dict(
        (h3_index, (severity / MAX_SEVERITY) / len(years))
        for h3_index, severity in commulative_severity.items()
    )


def compact_impacted_indexes(h3_indexes):
    h3_indexes_compacted = {}
    severity_key = lambda x: x[0]
    for severity, h3_indexes_for_severity in groupby(
        sorted(
            ((severity, h3_index) for (h3_index, severity) in h3_indexes.items()),
            key=severity_key,
        ),
        key=severity_key,
    ):
        compacted_cells = h3.compact_cells([h3_index for _, h3_index in h3_indexes_for_severity])
        for h3_index in compacted_cells:
            h3_indexes_compacted[h3_index] = severity
    return h3_indexes_compacted


severity_palette = {
    1: "#A8E6CF",  # Light Green (Lowest severity)
    2: "#6EC6FF",  # Soft Blue (Low-Moderate severity)
    3: "#FFD966",  # Yellow (Moderate severity)
    4: "#FFA500",  # Orange (High severity)
    5: "#FF5252",  # Red (Highest severity)
}


def display_h3_indexes(
    map,
    h3_indexes,
    properties_fn=lambda h3_data: {"severity": h3_data},
    style_fn=lambda feature: {
        "fillColor": severity_palette[feature["properties"]["severity"]],
        "color": severity_palette[feature["properties"]["severity"]],
        "weight": 1,
        "fillOpacity": 0.4,
    },
    tooltip_fn=lambda h3_index, h3_data: f"H3 Res: {h3.get_resolution(h3_index)} / Sev: {h3_data}",
    popup_fn=lambda h3_index, h3_data: f"<b>H3 Index:</b> {h3_index}<br><b>Resolution:</b> {h3.get_resolution(h3_index)}  <b>Severity:</b> {h3_data} ",
):
    """
    Display H3 indexes on an interactive map

    Args:
        map: Folium map where the indexes will be displayed
        h3_indexes: Dictionary of H3Index -> H3Data where H3data is the information to show
    """
    # Add each H3 cell to the map
    for h3_index, h3_data in h3_indexes.items():
        # Get the GeoJSON boundary coordinates
        boundary = h3.cell_to_boundary(h3_index)
        # Convert to GeoJSON format (close the polygon)
        boundary = [[lng, lat] for lat, lng in boundary]  # Folium expects [lng, lat]
        boundary.append(boundary[0])  # Close the loop

        # Create a GeoJSON polygon
        geojson = {
            "type": "Feature",
            "geometry": {"type": "Polygon", "coordinates": [boundary]},
            "properties": {
                "h3_index": h3_index,
                "resolution": h3.get_resolution(h3_index),
            }
            | properties_fn(h3_data),
        }

        # Add to map with popup
        folium.GeoJson(
            geojson,
            style_function=style_fn,
            tooltip=tooltip_fn(h3_index, h3_data),
            popup=popup_fn(h3_index, h3_data),
        ).add_to(map)

    # Display the map
    return map


def compute_centroid(h3_indexes):
    """Compute the centroid (mean lat/lng) of a set of H3 cells."""
    centers = [h3.cell_to_latlng(h) for h in h3_indexes]
    lats, lngs = zip(*centers)  # Unzip into separate lists
    return np.mean(lats), np.mean(lngs)


def display_storm_path(map, records):
    # Create a color scale for wind speed
    colormap = linear.YlOrRd_09.scale(
        min([point["max_sustained_wind"] for point in records]),
        max([point["max_sustained_wind"] for point in records]),
    )
    colormap.caption = "Wind Speed (knots)"

    # Add hurricane path (PolyLine)
    folium.PolyLine(
        # locations=[[point["lng"], point["lat"]] for point in records],
        locations=[[point["lat"], point["lng"]] for point in records],
        color="white",
        weight=2,
        opacity=0.7,
    ).add_to(map)

    # Add markers for each point with wind speed
    for point in records:
        folium.CircleMarker(
            location=[point["lat"], point["lng"]],
            radius=5 + (point["max_sustained_wind"] / 20),  # Scale marker size by wind speed
            color=colormap(point["max_sustained_wind"]),
            fill=True,
            fill_color=colormap(point["max_sustained_wind"]),
            popup=f"Wind: {point["max_sustained_wind"]} knots",
        ).add_to(map)


def parse_args(args):
    """Parse command line parameters

    Args:
      args (List[str]): command line parameters as list of strings
          (for example  ``["--help"]``).

    Returns:
      :obj:`argparse.Namespace`: command line parameters namespace
    """
    parser = argparse.ArgumentParser(
        description="Different commands to execute eth-pretty-events from command line"
    )
    parser.add_argument(
        "-v",
        "--verbose",
        dest="loglevel",
        help="set loglevel to INFO",
        action="store_const",
        const=logging.INFO,
    )
    parser.add_argument(
        "-vv",
        "--very-verbose",
        dest="loglevel",
        help="set loglevel to DEBUG",
        action="store_const",
        const=logging.DEBUG,
    )
    parser.add_argument(
        "--hurdat2",
        type=str,
        help="HURDAT2 filename",
        default="./hurdat2-1851-2024-040425.txt",
    )

    parser.add_argument(
        "--radius",
        type=float,
        help="Radius of affected areas in KM",
        default=50.0,
    )

    parser.add_argument(
        "--min-wind",
        type=int,
        help="Minimum wind speed in knots",
        default=64,
    )

    parser.add_argument("--resolution", type=int, help="Max H3 resolution to report", default=6)

    subparsers = parser.add_subparsers(dest="command", required=True, help="sub-command to run")

    affected_areas = subparsers.add_parser("affected_areas")

    affected_areas.add_argument("--storm", type=str, help="Id of the storm, e.g. AL092021")

    affected_areas.add_argument("--map-output", type=str, help="Output for the HTML map")

    price_list = subparsers.add_parser("price_list")

    price_list.add_argument(
        "--year-from",
        type=int,
        help="First year to consider",
        default=1950,
    )

    price_list.add_argument(
        "--year-to",
        type=int,
        help="Last year to consider",
        default=2024,
    )

    price_list.add_argument(
        "--min-loss-prob",
        type=float,
        help="Minimum loss probability",
        default=0.005,  # 0.5%
    )

    price_list.add_argument("--map-output", type=str, help="Output for the HTML map")

    return parser.parse_args(args)


def setup_logging(loglevel):
    """Setup basic logging

    Args:
      loglevel (int): minimum loglevel for emitting messages
    """
    logformat = "[%(asctime)s] %(levelname)s:%(name)s:%(message)s"
    logging.basicConfig(level=loglevel, stream=sys.stdout, format=logformat, datefmt="%Y-%m-%d %H:%M:%S")


def affected_areas_command(args):
    storm_data = hurdat2json.read_storm(args.hurdat2, args.storm)
    h3_indexes = find_impacted_indexes(
        storm_data,
        radius_km=args.radius,
        min_wind=args.min_wind,
        resolution=args.resolution,
    )
    if not h3_indexes:
        print(f"No h3 indexes in US found for {args.storm}")
        return

    h3_indexes_compacted = compact_impacted_indexes(h3_indexes)
    logger.info(f"Original H3 indexes {len(h3_indexes)} vs Compacted {len(h3_indexes_compacted)}")

    center_lat, center_lng = compute_centroid(h3_indexes_compacted.keys())
    map = folium.Map(location=[center_lat, center_lng], zoom_start=8)
    display_h3_indexes(map, h3_indexes_compacted)
    display_storm_path(map, storm_data["records"])
    map.save(args.map_output)


def price_list_command(args):
    h3_indexes = compute_price_list(
        args.hurdat2,
        years=list(range(args.year_from, args.year_to + 1)),
        find_indexes_fn=partial(
            find_impacted_indexes,
            radius_km=args.radius,
            min_wind=args.min_wind,
            resolution=args.resolution,
        ),
    )
    # Round to 3 decimals (E.g. 5.1%)
    h3_indexes = dict((k, round(v, 3)) for k, v in h3_indexes.items())

    # Complete all the h3 regions in US making sure they have at least the min_loss_prob
    all_us_indexes = sum(
        (h3.cell_to_children(h3_index, args.resolution) for h3_index in us_hexagons_extended),
        [],
    )
    all_us_indexes = dict((h3_index, args.min_loss_prob) for h3_index in all_us_indexes)
    _merge_into(all_us_indexes, h3_indexes, lambda a, b: a if a >= b else b)
    h3_indexes = all_us_indexes

    h3_indexes_compacted = compact_impacted_indexes(h3_indexes)

    logger.info(f"Original H3 indexes {len(h3_indexes)} vs Compacted {len(h3_indexes_compacted)}")
    center_lat, center_lng = compute_centroid(h3_indexes_compacted.keys())
    map = folium.Map(location=[center_lat, center_lng], zoom_start=8)

    colormap = linear.YlOrRd_09.scale(
        min(h3_indexes_compacted.values()),
        max(h3_indexes_compacted.values()),
    )
    colormap.caption = "Loss Prob"
    display_h3_indexes(
        map,
        h3_indexes_compacted,
        properties_fn=lambda h3_data: {"loss_prob": h3_data},
        style_fn=lambda feature: {
            "fillColor": colormap(feature["properties"]["loss_prob"]),
            "color": colormap(feature["properties"]["loss_prob"]),
            "weight": 1,
            "fillOpacity": 0.4,
        },
        tooltip_fn=lambda h3_index, h3_data: f"H3 Res: {h3.get_resolution(h3_index)} / LossProb: {h3_data * 100:.1f}%",
        popup_fn=lambda h3_index, h3_data: f"<b>H3 Index:</b> {h3_index}<br><b>Resolution:</b> {h3.get_resolution(h3_index)}  <b>LossProb:</b> {h3_data * 100:.1f}% ",
    )
    map.save(args.map_output)


def main(args):
    args = parse_args(args)
    setup_logging(args.loglevel)
    if args.command == "affected_areas":
        affected_areas_command(args)
    elif args.command == "price_list":
        price_list_command(args)


def run():
    """Calls :func:`main` passing the CLI arguments extracted from :obj:`sys.argv`

    This function can be used as entry point to create console scripts with setuptools.
    """
    main(sys.argv[1:])


if __name__ == "__main__":
    run()
