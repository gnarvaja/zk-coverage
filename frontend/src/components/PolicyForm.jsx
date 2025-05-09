import { useState, useRef } from "react";
import { useLoadScript } from "@react-google-maps/api";
import { Autocomplete } from "@react-google-maps/api";
import { latLngToCell } from "h3-js";
import "./PolicyForm.css";

function AddressInput({ onSelect }) {
  const { isLoaded } = useLoadScript({
    googleMapsApiKey: "AIzaSyBf6x7Fl9dEtngrrFEtwDtkMAWDykvLxlI",
    libraries: ["places"],
  });

  // Create a ref to store the Autocomplete instance
  const autocompleteRef = useRef(null);

  if (!isLoaded) return <div>Loading...</div>;

  const handlePlaceChanged = () => {
    // Access the Autocomplete instance via ref
    const autocomplete = autocompleteRef.current;
    if (!autocomplete) return;

    const place = autocomplete.getPlace();

    if (!place.geometry) {
      console.warn("No geometry available for this place");
      return;
    }

    const lat = place.geometry.location.lat();
    const lng = place.geometry.location.lng();

    // Return the full place object and coordinates
    onSelect({
      address: place.formatted_address,
      coordinates: { lat, lng },
      placeDetails: place,
    });
  };

  return (
    <Autocomplete
      onLoad={(autocomplete) => {
        autocompleteRef.current = autocomplete;
        autocomplete.setFields([
          "address_components",
          "geometry",
          "formatted_address",
        ]);
      }}
      onPlaceChanged={handlePlaceChanged}
      options={{
        types: ["geocode"],
        componentRestrictions: { country: "us" }, // Restrict to US addresses
      }}
    >
      <input
        type="text"
        placeholder="Enter address"
        style={{
          width: "100%",
          padding: "10px",
          fontSize: "16px",
        }}
        required
      />
    </Autocomplete>
  );
}

const PolicyForm = ({ onSubmit, onCancel }) => {
  const [formData, setFormData] = useState({
    name: "",
    salt: "",
    location: {
      latitude: "",
      longitude: "",
      h3Index: "",
    },
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    if (formData.location.h3Index === "") {
      alert("Please select the address");
      return;
    }
    // Convert string values to appropriate types
    const processedData = {
      ...formData,
      salt: Number(formData.salt),
      location: {
        latitude: Number(formData.location.latitude),
        longitude: Number(formData.location.longitude),
      },
      h3Index: {
        h3Index: "0x" + formData.location.h3Index,
        resolution: 12,
      },
    };
    onSubmit(processedData);
  };

  const handleAddressSelect = (location) => {
    console.log("Selected address:", location.address);
    console.log("Coordinates:", location.coordinates);
    setFormData((prev) => ({
      ...prev,
      location: {
        latitude: location.coordinates.lat,
        longitude: location.coordinates.lng,
        h3Index: latLngToCell(
          location.coordinates.lat,
          location.coordinates.lng,
          12,
        ),
      },
    }));
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    if (name.includes(".")) {
      const [parent, child] = name.split(".");
      setFormData((prev) => ({
        ...prev,
        [parent]: {
          ...prev[parent],
          [child]: value,
        },
      }));
    } else {
      setFormData((prev) => ({
        ...prev,
        [name]: value,
      }));
    }
  };

  const googleMapsLink = (location) =>
    `https://www.google.com/maps?q=${location.latitude},${location.longitude}`;

  return (
    <div className="policy-form">
      <h2>Create New Policy</h2>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="latitude">Address:</label>
          <AddressInput onSelect={handleAddressSelect} />
        </div>
        {formData.location.latitude && (
          <div className="form-group">
            <label>
              Lat: {formData.location.latitude} / Long:{" "}
              {formData.location.longitude}{" "}
              <a href={googleMapsLink(formData.location)} target="_blank">
                Check
              </a>{" "}
              <br />
              H3: {formData.location.h3Index}
            </label>
          </div>
        )}
        <div className="form-group">
          <label htmlFor="name">Policy Name:</label>
          <input
            type="text"
            id="name"
            name="name"
            value={formData.name}
            onChange={handleChange}
            required
          />
        </div>

        <div className="form-group">
          <label htmlFor="salt">Salt:</label>
          <input
            type="number"
            id="salt"
            name="salt"
            value={formData.salt}
            onChange={handleChange}
            required
          />
        </div>

        <div className="form-actions">
          <button type="button" onClick={onCancel} className="cancel-button">
            Cancel
          </button>
          <button type="submit" className="submit-button">
            Create Policy
          </button>
        </div>
      </form>
    </div>
  );
};

export default PolicyForm;
