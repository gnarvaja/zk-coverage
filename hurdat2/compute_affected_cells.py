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

logger.info("us_hexagons: {len(us_hexagons)} / Extended: {len(us_hexagons_extended)}")


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


def severity_function(radius_km, resolution, min_wind, distance, wind):
    """Function that computes the severity as a value between 1 and 10"""
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
    level2_neighbors = h3.grid_ring(h3_level2, k=1)
    for neightbor in level2_neighbors:
        hex_center = h3.cell_to_latlng(neightbor)
        distance = h3.great_circle_distance((lat, lng), hex_center, unit="km")
        if distance <= EDGE_LENGTH[2]:
            return True
    return False


def find_impacted_indexes(storm_data, radius_km, resolution, min_wind):
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
        logger.info(f"{len(h3_indexes)} found for {record}")

        # Add the new found indexes or the ones that have greater severity
        for h3_index, distance_severity in h3_indexes.items():
            if (
                h3_index not in impacted_h3_indexes
                or distance_severity > impacted_h3_indexes[h3_index]
            ):
                impacted_h3_indexes[h3_index] = distance_severity

    logger.info(f"Total Indexes: {len(impacted_h3_indexes)}")
    return impacted_h3_indexes


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
        compacted_cells = h3.compact_cells(
            [h3_index for _, h3_index in h3_indexes_for_severity]
        )
        for h3_index in compacted_cells:
            h3_indexes_compacted[h3_index] = severity
    return h3_indexes_compacted


severity_palette = {
    1: "#A8E6CF",  # Light Green (Lowest severity)
    2: "#6EC6FF",  # Soft Blue (Low-Moderate severity)
    3: "#FFD966",  # Yellow (Moderate severity)
    4: "#FFA500",  # Orange (High severity)
    5: "#FF5252"   # Red (Highest severity)
}

def display_h3_indexes(map, h3_indexes):
    """
    Display H3 indexes on an interactive map

    Args:
        map: Folium map where the indexes will be displayed
        h3_indexes: List of H3 indexes to display
    """
    # Add each H3 cell to the map
    for h3_index, severity in h3_indexes.items():
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
                "severity": severity,
            },
        }

        # Add to map with popup
        folium.GeoJson(
            geojson,
            style_function=lambda feature: {
                "fillColor": severity_palette[feature["properties"]["severity"]],
                "color": severity_palette[feature["properties"]["severity"]],
                "weight": 1,
                "fillOpacity": 0.4,
            },
            tooltip=f"H3 Res: {h3.get_resolution(h3_index)} / Sev: {severity}",
            popup=f"<b>H3 Index:</b> {h3_index}<br>"
            f"<b>Resolution:</b> {h3.get_resolution(h3_index)} <b>Severity:</b> {severity}",
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
        max([point["max_sustained_wind"] for point in records])
    )
    colormap.caption = "Wind Speed (knots)"

    # Add hurricane path (PolyLine)
    folium.PolyLine(
        # locations=[[point["lng"], point["lat"]] for point in records],
        locations=[[point["lat"], point["lng"]] for point in records],
        color="white",
        weight=2,
        opacity=0.7
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

if __name__ == "__main__":
    import sys

    storm_data = hurdat2json.read_storm(sys.argv[1], sys.argv[2])
    h3_indexes = find_impacted_indexes(
        storm_data, float(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    )
    if h3_indexes:
        h3_indexes_compacted = compact_impacted_indexes(h3_indexes)
        logger.info(
            f"Original H3 indexes {len(h3_indexes)} vs Compacted {len(h3_indexes_compacted)}"
        )

        center_lat, center_lng = compute_centroid(h3_indexes_compacted.keys())
        map = folium.Map(location=[center_lat, center_lng], zoom_start=8)
        display_h3_indexes(map, h3_indexes_compacted)
        display_storm_path(map, storm_data["records"])
        map.save(sys.argv[6])
    else:
        print(f"No h3 indexes in US found for {sys.argv[2]}")
