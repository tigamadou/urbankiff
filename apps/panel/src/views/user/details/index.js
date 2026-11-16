// ** Reactstrap Imports
import { Row, Col, Alert } from "reactstrap"

// ** User View Components
import UserInfoCard from "./UserInfoCard"

// ** Styles
import "@styles/react/apps/app-users.scss"
import { useSelector } from "react-redux"

const UserView = () => {
  // ** Store Vars
  const userData = useSelector(state => state.auth.userData)

  // ** Get suer on mount

  // const [active, setActive] = useState('1')

  // const toggleTab = tab => {
  //   if (active !== tab) {
  //     setActive(tab)
  //   }
  // }

  return userData !== null && userData !== undefined ? (
    <div className="app-user-view">
      <Row>
        {/* Colonne UserInfoCard */}
        <Col xl="5" lg="6">
          <UserInfoCard key={userData.id} selectedUser={userData} />
        </Col>

        {/* Colonne UserStatsCard */}
        <Col xl="7" lg="6">
        </Col>
      </Row>
    </div>
  ) : (
    <Alert color="danger">
      <h4 className="alert-heading">User not found</h4>
      <div className="alert-body">
       Failes to get User info

      </div>
    </Alert>
  )
}
export default UserView
