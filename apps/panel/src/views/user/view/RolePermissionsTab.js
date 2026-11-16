// ** React Imports
import { Fragment, useState } from 'react'

// ** Reactstrap Imports
import { 
  Card, 
  CardHeader, 
  CardTitle, 
  CardBody, 
  Row, 
  Col, 
  Badge, 
  Table, 
  Form, 
  FormGroup, 
  Label, 
  Input, 
  Button
} from 'reactstrap'

const RolePermissionsTab = () => {
  // State for current user role
  const [currentRole, setCurrentRole] = useState('Administrator')
  // State for edit mode
  const [isEditingRole, setIsEditingRole] = useState(false)
  
  // Available roles
  const roles = ['Administrator', 'Editor', 'Contributor', 'Subscriber']
  
  // Available permissions
  const permissions = [
    { id: 'read_posts', name: 'Read Posts', description: 'View and read posts' },
    { id: 'write_posts', name: 'Write Posts', description: 'Create and edit posts' },
    { id: 'delete_posts', name: 'Delete Posts', description: 'Delete posts' },
    { id: 'publish_posts', name: 'Publish Posts', description: 'Publish posts' },
    { id: 'read_pages', name: 'Read Pages', description: 'View and read pages' },
    { id: 'write_pages', name: 'Write Pages', description: 'Create and edit pages' },
    { id: 'delete_pages', name: 'Delete Pages', description: 'Delete pages' },
    { id: 'manage_users', name: 'Manage Users', description: 'Create, edit, and delete users' },
    { id: 'manage_roles', name: 'Manage Roles', description: 'Assign and modify user roles' },
    { id: 'manage_categories', name: 'Manage Categories', description: 'Create and manage categories' },
    { id: 'manage_comments', name: 'Manage Comments', description: 'Moderate and manage comments' },
    { id: 'view_reports', name: 'View Reports', description: 'Access system reports' },
    { id: 'manage_settings', name: 'Manage Settings', description: 'Modify system settings' },
    { id: 'access_analytics', name: 'Access Analytics', description: 'View analytics and statistics' }
  ]
  
  // Permissions matrix - which roles have which permissions
  const permissionsMatrix = {
    Administrator: {
      read_posts: true,
      write_posts: true,
      delete_posts: true,
      publish_posts: true,
      read_pages: true,
      write_pages: true,
      delete_pages: true,
      manage_users: true,
      manage_roles: true,
      manage_categories: true,
      manage_comments: true,
      view_reports: true,
      manage_settings: true,
      access_analytics: true
    },
    Editor: {
      read_posts: true,
      write_posts: true,
      delete_posts: true,
      publish_posts: true,
      read_pages: true,
      write_pages: true,
      delete_pages: false,
      manage_users: false,
      manage_roles: false,
      manage_categories: true,
      manage_comments: true,
      view_reports: true,
      manage_settings: false,
      access_analytics: true
    },
    Contributor: {
      read_posts: true,
      write_posts: true,
      delete_posts: false,
      publish_posts: false,
      read_pages: true,
      write_pages: false,
      delete_pages: false,
      manage_users: false,
      manage_roles: false,
      manage_categories: false,
      manage_comments: false,
      view_reports: false,
      manage_settings: false,
      access_analytics: false
    },
    Subscriber: {
      read_posts: true,
      write_posts: false,
      delete_posts: false,
      publish_posts: false,
      read_pages: true,
      write_pages: false,
      delete_pages: false,
      manage_users: false,
      manage_roles: false,
      manage_categories: false,
      manage_comments: false,
      view_reports: false,
      manage_settings: false,
      access_analytics: false
    }
  }
  
  // State for permissions matrix
  const [permissionsState, setPermissionsState] = useState(permissionsMatrix)
  
  // Handle permission toggle
  const handlePermissionToggle = (role, permission) => {
    setPermissionsState(prev => ({
      ...prev,
      [role]: {
        ...prev[role],
        [permission]: !prev[role][permission]
      }
    }))
  }
  
  // Handle role change
  const handleRoleChange = (newRole) => {
    setCurrentRole(newRole)
  }
  
  // Handle edit mode toggle
  const handleEditRole = () => {
    setIsEditingRole(true)
  }
  
  // Handle cancel edit
  const handleCancelEdit = () => {
    setIsEditingRole(false)
  }
  
  // Handle save role
  const handleSaveRole = () => {
    // Here you would typically send the role change to your API
    console.log('Saving role change:', currentRole)
    setIsEditingRole(false)
    // Add your API call here
    alert(`Role changed to ${currentRole} successfully!`)
  }

  // Handle bulk select all for a role
  const handleBulkSelectRole = (role, selectAll) => {
    const newPermissions = {}
    permissions.forEach(permission => {
      newPermissions[permission.id] = selectAll
    })
    
    setPermissionsState(prev => ({
      ...prev,
      [role]: newPermissions
    }))
  }
  
  // Handle bulk select all for a permission
  const handleBulkSelectPermission = (permission, selectAll) => {
    setPermissionsState(prev => {
      const newState = { ...prev }
      roles.forEach(role => {
        newState[role] = {
          ...newState[role],
          [permission]: selectAll
        }
      })
      return newState
    })
  }

  return (
    <Fragment>
      {/* Current Role Section */}
      <Row className="mb-3">
        <Col lg="12">
          <Card>
            <CardHeader>
              <CardTitle tag="h4">Current User Role</CardTitle>
            </CardHeader>
            <CardBody>
              <Row>
                <Col md="6">
                  <h6 className="mb-2">Current Role</h6>
                  <Badge color="primary" className="mb-3" style={{ fontSize: '1rem', padding: '0.5rem 1rem' }}>
                    {currentRole}
                  </Badge>
                </Col>
                <Col md="6" className="d-flex align-items-end">
                  {!isEditingRole ? (
                    <Button color="primary" onClick={handleEditRole}>
                      Edit Role
                    </Button>
                  ) : (
                    <div className="w-100">
                      <Form>
                        <FormGroup>
                          <Label for="roleSelect">Change Role</Label>
                          <Input
                            type="select"
                            name="roleSelect"
                            id="roleSelect"
                            value={currentRole}
                            onChange={(e) => handleRoleChange(e.target.value)}
                          >
                            {roles.map(role => (
                              <option key={role} value={role}>{role}</option>
                            ))}
                          </Input>
                        </FormGroup>
                      </Form>
                      <div className="d-flex gap-2 mt-2">
                        <Button color="success" size="sm" onClick={handleSaveRole}>
                          Save
                        </Button>
                        <Button color="secondary" size="sm" onClick={handleCancelEdit}>
                          Cancel
                        </Button>
                      </div>
                    </div>
                  )}
                </Col>
              </Row>
            </CardBody>
          </Card>
        </Col>
      </Row>

      {/* Permissions Matrix */}
      <Row>
        <Col lg="12">
          <Card>
            <CardHeader>
              <CardTitle tag="h4">Permissions Matrix</CardTitle>
              <p className="mb-0">Configure permissions for each role. Checkboxes indicate which permissions each role has.</p>
            </CardHeader>
            <CardBody>
              <div className="table-responsive">
                <Table bordered striped>
                  <thead>
                    <tr>
                      <th style={{ minWidth: '200px' }}>
                        Permission
                        <div className="mt-2">
                          <Button 
                            size="sm" 
                            color="outline-primary" 
                            onClick={() => handleBulkSelectPermission('all', true)}
                            className="me-1"
                          >
                            Select All
                          </Button>
                          <Button 
                            size="sm" 
                            color="outline-secondary" 
                            onClick={() => handleBulkSelectPermission('all', false)}
                          >
                            Clear All
                          </Button>
                        </div>
                      </th>
                      {roles.map(role => (
                        <th key={role} className="text-center" style={{ minWidth: '120px' }}>
                          {role}
                          <div className="mt-2">
                            <Button 
                              size="sm" 
                              color="outline-primary" 
                              onClick={() => handleBulkSelectRole(role, true)}
                              className="me-1"
                            >
                              All
                            </Button>
                            <Button 
                              size="sm" 
                              color="outline-secondary" 
                              onClick={() => handleBulkSelectRole(role, false)}
                            >
                              None
                            </Button>
                          </div>
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {permissions.map(permission => (
                      <tr key={permission.id}>
                        <td>
                          <div>
                            <strong>{permission.name}</strong>
                            <br />
                            <small className="text-muted">{permission.description}</small>
                          </div>
                        </td>
                        {roles.map(role => (
                          <td key={`${permission.id}-${role}`} className="text-center">
                            <Input
                              type="checkbox"
                              id={`${permission.id}-${role}`}
                              checked={permissionsState[role]?.[permission.id] || false}
                              onChange={() => handlePermissionToggle(role, permission.id)}
                            />
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </Table>
              </div>
            </CardBody>
          </Card>
        </Col>
      </Row>
    </Fragment>
  )
}

export default RolePermissionsTab
