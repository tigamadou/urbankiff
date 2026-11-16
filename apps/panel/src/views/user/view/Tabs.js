// ** React Imports
import { Fragment, useEffect, useState } from 'react'

// ** Reactstrap Imports
import { Nav, NavItem, NavLink, TabContent, TabPane } from 'reactstrap'

// ** Icons Imports
import { User, Lock, Bookmark, Bell, Link, FileText } from 'react-feather'

// ** User Components
import InvoiceList from './InvoiceList'
import SecurityTab from './SecurityTab'
import Connections from './Connections'
import BillingPlanTab from './BillingTab'
import UserTimeline from './UserTimeline'
import Notifications from './Notifications'
import UserProjectsList from './UserProjectsList'

// ** Tab Components
import AccountTab from './AccountTab'
import RolePermissionsTab from './RolePermissionsTab'
import PostsTab from './PostsTab'
import CommentsTab from './CommentsTab'
import LikesTab from './LikesTab'
import ActivityTab from './ActivityTab'

const UserTabs = ({ selectedUser}) => {
  const [active, setActive] = useState('account')
  const toggleTab = (tab) => {
    setActive(tab)
  }
  useEffect(() => {
    console.log({selectedUser})
  }, [selectedUser])
  return (
    <Fragment>
      <Nav tabs className='mb-2'>
        <NavItem className='bg-white p-1'>
          <NavLink active={active === 'account'} onClick={() => toggleTab('account')}>
            <User className='font-medium-3 me-50' />
            <span className='fw-bold'>Account</span>
          </NavLink>
          
        </NavItem>
        <NavItem className='bg-white p-1'>
          <NavLink active={active === 'role_permissions'} onClick={() => toggleTab('role_permissions')}>
            <FileText className='font-medium-3 me-50' />
            <span className='fw-bold'>Role & Permissions</span>
          </NavLink>
        </NavItem>
        <NavItem className='bg-white p-1'>
          <NavLink active={active === 'posts'} onClick={() => toggleTab('posts')}>
            <FileText className='font-medium-3 me-50' />
            <span className='fw-bold'>Posts</span>
          </NavLink>
        </NavItem>
        <NavItem className='bg-white p-1'>
          <NavLink active={active === 'comments'} onClick={() => toggleTab('comments')}>
            <FileText className='font-medium-3 me-50' />
            <span className='fw-bold'>Comments</span>
          </NavLink>
        </NavItem>
        <NavItem className='bg-white p-1'>
          <NavLink active={active === 'likes'} onClick={() => toggleTab('likes')}>
            <FileText className='font-medium-3 me-50' />
            <span className='fw-bold'>Likes</span>
          </NavLink>
        </NavItem>
        <NavItem className='bg-white p-1'>
          <NavLink active={active === 'activity'} onClick={() => toggleTab('activity')}>
            <FileText className='font-medium-3 me-50' />
            <span className='fw-bold'>Activity</span>
          </NavLink>
        </NavItem>
        

      </Nav>
      <TabContent activeTab={active}>
        <TabPane tabId='account'>
          <AccountTab selectedUser={selectedUser} />
        </TabPane>
        <TabPane tabId='role_permissions'>
          <RolePermissionsTab />
        </TabPane>
        <TabPane tabId='posts'>
          <PostsTab />
        </TabPane>
        <TabPane tabId='comments'>
          <CommentsTab />
        </TabPane>
        <TabPane tabId='likes'>
          <LikesTab />
        </TabPane>
        <TabPane tabId='activity'>
          <ActivityTab />
        </TabPane>
      </TabContent>
    </Fragment>
  )
}
export default UserTabs
