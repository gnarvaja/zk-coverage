import './Sidebar.css';

const Sidebar = ({ policies, selectedPolicy, onSelectPolicy }) => {
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
    </div>
  );
};

export default Sidebar;
