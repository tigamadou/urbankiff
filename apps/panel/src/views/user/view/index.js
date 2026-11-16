// ** React Imports
import { useParams, Link, useLocation } from "react-router-dom"

// ** Reactstrap Imports
import { Row, Col, Alert } from "reactstrap"

// ** User View Components
import UserTabs from "./Tabs"
import PlanCard from "./PlanCard"
import UserInfoCard from "./UserInfoCard"
import UserStatsCard from "./UserStatsCard"

// ** Styles
import "@styles/react/apps/app-users.scss"

const UserView = () => {
  // ** Store Vars
  const location = useLocation()
  const { state } = location
  // ** Hooks
  const { id } = useParams()

  // ** Get suer on mount

  // const [active, setActive] = useState('1')

  // const toggleTab = tab => {
  //   if (active !== tab) {
  //     setActive(tab)
  //   }
  // }

  return state !== null && state !== undefined ? (
    <div className="app-user-view">
      <Row>
        {/* Colonne UserInfoCard */}
        <Col xl="24" lg="24">
          <UserTabs key={state.id} selectedUser={state} />
        </Col>

        {/* Colonne UserStatsCard */}
        <Col xl="8" lg="8">
          {/* <UserStatsCard userStats={randomStats} /> */}
        </Col>
      </Row>
    </div>
  ) : (
    <Alert color="danger">
      <h4 className="alert-heading">User not found</h4>
      <div className="alert-body">
        User with id: {id} doesn't exist. Check list of all Users:{" "}
        <Link to="/user/list">Users List</Link>
      </div>
    </Alert>
  )
}
export default UserView
