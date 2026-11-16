// ** React Imports
import { Link } from "react-router-dom"

// ** Custom Components
import Avatar from "@components/avatar"

// ** Store & Actions
// import { store } from '@store/store'
// import { deleteUser } from '../store'

// ** Icons Imports
import {
  Slack,
  User,
  Settings,
  Database,
  Edit2,
  MoreVertical,
  FileText,
  Trash2,
  Archive
} from "react-feather"

// ** Reactstrap Imports
import {
  Badge,
  UncontrolledDropdown,
  DropdownToggle,
  DropdownMenu,
  DropdownItem
} from "reactstrap"

import { useState } from "react"
import DeleteModal from "./DeleteModal"

// ** Renders Client Columns
const renderClient = (row) => {
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

  if (row.avatar) {
    return (
      <Avatar className="me-1" img={`${process.env.REACT_APP_BACKEND_URL}/file/${row.avatar}`}  style={{
        height: "32px",
        width: "32px"
      }} imgHeight="30"/>
    )
  } else {
    return (
      <Avatar
        color={color || "primary"}
        className="me-1"
        content={`${row.firstname} ${row.lastname}` || "John Doe"}
        initials
      />
    )
  }
}

// ** Renders Role Columns
const renderRole = (row) => {
  const roleObj = {
    subscriber: {
      class: "text-primary",
      icon: User
    },
    maintainer: {
      class: "text-success",
      icon: Database
    },
    editor: {
      class: "text-info",
      icon: Edit2
    },
    author: {
      class: "text-warning",
      icon: Settings
    },
    admin: {
      class: "text-danger",
      icon: Slack
    }
  }

  const Icon = roleObj[row.role] ? roleObj[row.role].icon : Edit2

  return (
    <span className="text-truncate text-capitalize align-middle">
      {row.role}
    </span>
  )
}

const statusObj = {
  pending: "light-warning",
  active: "light-success",
  inactive: "light-secondary"
}

export const columns = [
  {
    name: "User",
    nameKey: "user",
    sortable: false,
    minWidth: "300px",
    sortField: "fullName",
    selector: (row) => row.firstname,
    cell: (row) => (
      <div className="d-flex justify-content-left align-items-center">
        {renderClient(row)}
        <div className="d-flex flex-column">
          <Link
            to={{ pathname: `/user/view/${row.id}`, state: row }}
            className="user_name text-truncate text-body"
          >
            <span className="fw-bolder">{`${row.firstname} ${row.lastname}`}</span>
          </Link>
          <small className="text-truncate text-muted mb-0">{row.email}</small>
        </div>
      </div>
    )
  },
  {
    name: "Role",
    nameKey: "role",
    sortable: false,
    minWidth: "172px",
    sortField: "role",
    selector: (row) => row.role,
    cell: (row) => renderRole(row)
  },
  {
    name: "Status",
    nameKey: "status",
    minWidth: "138px",
    sortable: false,
    sortField: "status",
    selector: (row) => row.status,
    cell: (row) => (
      <Badge className="text-capitalize" color={statusObj[row.status]} pill>
        {row.status}
      </Badge>
    )
  },
  {
    name: "Deleted",
    nameKey: "deleted",
    minWidth: "138px",
    sortable: false,
    sortField: "deleted",
    selector: (row) => row.deleted,
    cell: (row) => (
      <Badge
        className="text-capitalize"
        color={row.deleted ? "danger" : "success"}
        pill
      >
        {row.deleted ? "yes" : "no"}
      </Badge>
    )
  },
  {
    name: "Actions",
    nameKey: "actions",
    minWidth: "100px",
    cell: (row) => {
      const [modal, setModal] = useState(false)
      return (
        <div className="column-action">
          <div className="column-action d-flex align-items-center">
            <Link
              className="w-100"
              to={{ pathname: `/user/view/${row.id}`, state: row }}
            >
              <FileText size={14} className="mx-1" />
            </Link>
            <Link
              to="#"
              className="w-100"
              onClick={() => {
                setModal(!modal)
              }}
            >
              <Trash2 size={14} className="mx-1" />
            </Link>
          </div>
          <DeleteModal modal={modal} setModal={setModal} row={row} />
        </div>
      )
    }
  }
]
