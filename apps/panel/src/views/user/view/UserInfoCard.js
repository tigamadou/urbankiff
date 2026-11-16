// ** React Imports
import { Fragment } from "react"

// ** Reactstrap Imports
import {
  Card,
  CardBody,
  Badge,
  Spinner
} from "reactstrap"

// ** Third Party Components

// ** Custom Components
import Avatar from "@components/avatar"

const roleColors = {
  editor: "light-info",
  admin: "light-danger",
  author: "light-warning",
  maintainer: "light-success",
  subscriber: "light-primary"
}

const statusColors = {
  active: "light-success",
  pending: "light-warning",
  inactive: "light-secondary"
}

const UserInfoCard = ({ selectedUser }) => {
  const thumbnailImgUrl = selectedUser?.avatar ? `${process.env.REACT_APP_BACKEND_URL}/file/${selectedUser.avatar}` : ''

  // ** Show loading state if selectedUser is not available
  if (!selectedUser) {
    return (
      <div className="d-flex justify-content-center align-items-center" style={{ height: '200px' }}>
        <Spinner color="primary" />
      </div>
    )
  }

  const renderUserImg = () => {
    if (selectedUser !== null && selectedUser.avatar) {
      return (
        <Avatar
          initials={false}
          className="rounded mt-3 mb-2 rounded-circle" 
          style={{
            height: "200px",
            width: "200px"
          }}
          img={`${thumbnailImgUrl}`}
          imgWidth='300' 
          status='online'
        />
      )
    } else {
      const stateNum = Math.floor(Math.random() * 6),
        states = [
          "light-success",
          "light-danger",
          "light-warning",
          "light-info",
          "light-primary",
          "light-secondary"
        ],
        color = states[stateNum]
      return (
        <Avatar
          initials
          color={color}
          className="rounded mt-3 mb-2"
          content={`${selectedUser.lastname} ${selectedUser.firstname}`}
          contentStyles={{
            borderRadius: 0,
            fontSize: "calc(48px)",
            width: "100%",
            height: "100%"
          }}
          style={{
            height: "200px",
            width: "200px"
          }}
        />
      )
    }
  }

  return (
    <Fragment>
      <Card>
        <CardBody>
          <div className="user-avatar-section">
            <div className="d-flex align-items-center flex-column">
              {renderUserImg()}
              <div className="d-flex flex-column align-items-center text-center">
                <div className="user-info">
                  <h3>
                    {selectedUser !== null ? `${selectedUser.firstname} ${selectedUser.lastname}` : "Eleanor Aguilar"}
                  </h3>
                  {selectedUser !== null ? (
                    <><Badge
                      color={roleColors[selectedUser.role]}
                      className="text-capitalize"
                    >
                      {selectedUser.role}
                    </Badge><Badge
                      className="text-capitalize"
                      color={statusColors[selectedUser.status]}
                    >
                        {selectedUser.status}
                      </Badge></>
                  ) : null}
                </div>
              </div>
            </div>
          </div>
        </CardBody>
      </Card>
    </Fragment>
  )
}

export default UserInfoCard
