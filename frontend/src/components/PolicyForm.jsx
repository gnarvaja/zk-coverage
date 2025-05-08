import { useState } from 'react';
import './PolicyForm.css';

const PolicyForm = ({ onSubmit, onCancel }) => {
  const [formData, setFormData] = useState({
    name: '',
    salt: '',
    location: {
      latitude: '',
      longitude: ''
    }
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    // Convert string values to appropriate types
    const processedData = {
      ...formData,
      salt: Number(formData.salt),
      location: {
        latitude: Number(formData.location.latitude),
        longitude: Number(formData.location.longitude)
      },
      h3Index: {
        h3Index: "0x8c26400000001ff", // You might want to calculate this based on lat/long
        resolution: 12
      }
    };
    onSubmit(processedData);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    if (name.includes('.')) {
      const [parent, child] = name.split('.');
      setFormData(prev => ({
        ...prev,
        [parent]: {
          ...prev[parent],
          [child]: value
        }
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        [name]: value
      }));
    }
  };

  return (
    <div className="policy-form">
      <h2>Create New Policy</h2>
      <form onSubmit={handleSubmit}>
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

        <div className="form-group">
          <label htmlFor="latitude">Latitude:</label>
          <input
            type="number"
            id="latitude"
            name="location.latitude"
            value={formData.location.latitude}
            onChange={handleChange}
            step="any"
            required
          />
        </div>

        <div className="form-group">
          <label htmlFor="longitude">Longitude:</label>
          <input
            type="number"
            id="longitude"
            name="location.longitude"
            value={formData.location.longitude}
            onChange={handleChange}
            step="any"
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
