// ** React Imports
import { Fragment } from 'react'

// ** Reactstrap Imports
import { Card, CardHeader, CardTitle, CardBody, Row, Col, Table } from 'reactstrap'

const LikesTab = () => {
  // Mock data - replace with actual data from props or API
  const likes = [
    { id: 1, type: "Post", title: "Sample Post 1", date: "2024-01-15" },
    { id: 2, type: "Comment", title: "Great article!", date: "2024-01-14" },
    { id: 3, type: "Post", title: "Sample Post 3", date: "2024-01-13" }
  ]

  return (
    <Fragment>
      <Row>
        <Col lg="12">
          <Card>
            <CardHeader>
              <CardTitle tag="h4">User Likes</CardTitle>
            </CardHeader>
            <CardBody>
              <Table responsive>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Type</th>
                    <th>Title</th>
                    <th>Date</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {likes.map(like => (
                    <tr key={like.id}>
                      <td>{like.id}</td>
                      <td>
                        <span className={`badge ${like.type === 'Post' ? 'bg-primary' : 'bg-info'}`}>
                          {like.type}
                        </span>
                      </td>
                      <td>{like.title}</td>
                      <td>{like.date}</td>
                      <td>
                        <button className="btn btn-sm btn-outline-primary">View</button>
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

export default LikesTab

