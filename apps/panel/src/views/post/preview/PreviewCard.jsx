// ** Reactstrap Imports
import React, { useState } from 'react'
import { Card, CardBody, CardText, Row, Col, Table, Badge } from "reactstrap"
import CommentList from "./Comment/CommentList"
import "./preview_card.sass"

const PreviewCard = ({ data }) => {
  const [isLoaded, setIsLoaded] = useState(false)

  const handleImageLoad = () => {
    setIsLoaded(true)
  }
  return data !== null ? (
    <Card className="preview_card">
      <CardBody className="invoice-padding pb-0">
        <div className="d-flex justify-content-between flex-md-row flex-column invoice-spacing mt-0">
          <div className="mt-md-0 mt-2">
            <h4>{data.title}</h4>

            <div>
              <span className="">
                {data.published ? (
                  <Badge size="small" color="success">
                    Publié
                  </Badge>
                ) : (
                  data.deleted && (
                    <Badge size="small" color="danger">
                      Deleted
                    </Badge>
                  )
                )}
              </span>
            </div>
          </div>
        </div>

        <div className="preview_card_cover" >
          <div className="preview_card_blur" style={{ backgroundImage: `url(${data.image})` }}></div>
          <img
            className={`preview_card_cover_image  ${isLoaded ? 'is-loaded' : ''}`}
            src={`${data.image}`}
            onLoad={handleImageLoad}
            alt={data.title}
          />
        </div>
        <div className='d-flex gap-1 mb-2'>
              {data.tags.map((tag) => (
                <Badge size="small" color="secondary">
                  # {tag.name}
                </Badge>
              ))}
        </div>
        <p>{data.intro}</p>
        <p dangerouslySetInnerHTML={{ __html: data.content }}></p>
        <CommentList postId={data.id} />
      </CardBody>
    </Card>
  ) : null
}

export default PreviewCard
