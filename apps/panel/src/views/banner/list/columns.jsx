// ** React Imports
import { Fragment, useState } from "react"
import { Link } from "react-router-dom"

// ** Custom Components
import Avatar from "@components/avatar"

// ** Store & Actions

// ** Reactstrap Imports
import {
  Badge,
  DropdownItem,
  DropdownMenu,
  DropdownToggle,
  UncontrolledTooltip,
  UncontrolledDropdown
} from "reactstrap"

// ** Third Party Components
import {
  Eye,
  Send,
  Edit,
  Copy,
  Save,
  Info,
  Trash,
  PieChart,
  Download,
  TrendingUp,
  CheckCircle,
  MoreVertical,
  ArrowDownCircle
} from "react-feather"

import DeleteModal from "./DeleteModal"

// ** Vars

// ** renders client column

// ** Table columns
export const columns = [
  {
    name: "Title",
    nameKey: "title",
    sortable: false,
    minWidth: "80%",
    sortField: "client.name",
    // selector: row => row.client.name,
    cell: (row) => {
      const title = row.uuid ? row.uuid : ""
      return (
        <Link
          to={{ pathname: `/banner/preview/${row.id}`, state: row }}
          id={`pw-tooltip-${row.id}`}
          style={{ color: "#000" }}
        >
          <span className="user-name text-truncate mb-0">{title}</span>
        </Link>
      )
    }
  },


  {
    sortable: false,
    name: "N° Medias",
    nameKey: "medias",
    maxWidth: "50px",
    sortField: "balance",
    // selector: row => row.balance,
    cell: (row) => {
      if (row.medias) {
        return <Badge color="light-success">{row.medias?.length}</Badge>
      }
    }
  },
  {
    name: "Actions",
    nameKey: "actions",
    minWidth: "110px",
    cell: (row) => {
      const [modal, setModal] = useState(false)
      return (
        <>
          {row.deleted ? (
            <Badge color="light-danger">Post Deleted</Badge>
          ) : (
            <div className="column-action d-flex align-items-center">
              <Link
                to={{ pathname: `/banner/preview/${row.id}`, state: row }}
                id={`pw-tooltip-${row.id}`}
              >
                <Eye size={17} className="mx-1" />
              </Link>
              {/* <Link
                to={{ pathname: `/post/edit/${row.id}`, state: row }}
                id={`pw-tooltip-${row.id}`}
              >
                <Edit size={17} className="mx-1" />
              </Link> */}
              <span
                onClick={() => setModal(true)}
                style={{ cursor: "pointer" }}
              >
                <Trash size={17} className="mx-1" />
              </span>
              <UncontrolledTooltip
                placement="top"
                target={`pw-tooltip-${row.id}`}
              >
                Preview Post
              </UncontrolledTooltip>

              <DeleteModal modal={modal} setModal={setModal} row={row} />
            </div>
          )}
        </>
      )
    }
  }
]
