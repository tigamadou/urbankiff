// ** React Imports
import { Fragment } from 'react'

// ** Reactstrap Imports
import { Card, CardHeader, CardTitle, CardBody, Row, Col, Table } from 'reactstrap'

const PostsTab = () => {
  // Mock data - replace with actual data from props or API
  const posts = [
    { id: 1, title: "Sample Post 1", status: "Published", date: "2024-01-15" },
    { id: 2, title: "Sample Post 2", status: "Draft", date: "2024-01-14" },
    { id: 3, title: "Sample Post 3", status: "Published", date: "2024-01-13" }
  ]

  return (
    <Fragment>
      <Row>
        <Col lg="12">
          <Card>
            <CardHeader>
              <CardTitle tag="h4">User Posts</CardTitle>
            </CardHeader>
            <CardBody>
              <Table responsive>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Title</th>
                    <th>Status</th>
                    <th>Date</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {posts.map(post => (
                    <tr key={post.id}>
                      <td>{post.id}</td>
                      <td>{post.title}</td>
                      <td>
                        <span className={`badge ${post.status === 'Published' ? 'bg-success' : 'bg-warning'}`}>
                          {post.status}
                        </span>
                      </td>
                      <td>{post.date}</td>
                      <td>
                        <button className="btn btn-sm btn-outline-primary me-1">View</button>
                        <button className="btn btn-sm btn-outline-secondary">Edit</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            </CardBody>
          </Card>
        </Col>
      </Row>
    </Fragment>
  )
}

export default PostsTab

