// ** React Imports
import { Fragment } from 'react'

// ** Reactstrap Imports
import { Card, CardHeader, CardTitle, CardBody, Row, Col, Table } from 'reactstrap'

const CommentsTab = () => {
  // Mock data - replace with actual data from props or API
  const comments = [
    { id: 1, content: "Great article!", post: "Sample Post 1", date: "2024-01-15", status: "Approved" },
    { id: 2, content: "Very informative", post: "Sample Post 2", date: "2024-01-14", status: "Pending" },
    { id: 3, content: "Thanks for sharing", post: "Sample Post 3", date: "2024-01-13", status: "Approved" }
  ]

  return (
    <Fragment>
      <Row>
        <Col lg="12">
          <Card>
            <CardHeader>
              <CardTitle tag="h4">User Comments</CardTitle>
            </CardHeader>
            <CardBody>
              <Table responsive>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Content</th>
                    <th>Post</th>
                    <th>Date</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {comments.map(comment => (
                    <tr key={comment.id}>
                      <td>{comment.id}</td>
                      <td>{comment.content}</td>
                      <td>{comment.post}</td>
                      <td>{comment.date}</td>
                      <td>
                        <span className={`badge ${comment.status === 'Approved' ? 'bg-success' : 'bg-warning'}`}>
                          {comment.status}
                        </span>
                      </td>
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

export default CommentsTab

