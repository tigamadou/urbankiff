// ** React Imports
import { Fragment } from 'react'

// ** Reactstrap Imports
import { Row, Col } from 'reactstrap'

// ** User Components
import UserInfoCard from './UserInfoCard'
import UserEditView from './UserEditView'

const AccountTab = ({ selectedUser }) => {
  return (
    <Fragment>
      <Row>
        <Col lg="3">
          <UserInfoCard selectedUser={selectedUser} />
        </Col>
        <Col lg="9">
          <UserEditView selectedUser={selectedUser} />
        </Col>
      </Row>
    </Fragment>
  )
}

export default AccountTab
