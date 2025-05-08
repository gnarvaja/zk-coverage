import './Sidebar.css';

const Sidebar = ({ policies, selectedPolicy, onSelectPolicy, onCreatePolicy, onFileUpload, onDownload }) => {
  return (
    <div className="sidebar">
      <h2 className="sidebar-title">Policies</h2>
      <div className="policy-list">
        {policies.map((policy, index) => (
          <div
            key={index}
            className={`policy-item ${selectedPolicy === policy ? 'selected' : ''}`}
            onClick={() => onSelectPolicy(policy)}
          >
            {policy.name}
          </div>
        ))}
      </div>
      <div className="sidebar-actions">
        <button className="sidebar-button create-policy-button" onClick={onCreatePolicy}>
          Create Policy
        </button>
        <label className="sidebar-button upload-button">
          Upload Policy JSON
          <input
            type="file"
            accept=".json"
            onChange={onFileUpload}
            style={{ display: 'none' }}
          />
        </label>
        <button className="sidebar-button download-button" onClick={onDownload}>
          Download Policies
        </button>
      </div>
    </div>
  );
};

export default Sidebar;
