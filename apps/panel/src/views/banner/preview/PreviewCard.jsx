// ** Reactstrap Imports
import React, { useState } from "react"
import { Card, CardBody, CardText, Row, Col, Table, Badge } from "reactstrap"
import "./preview_card.sass"

const PreviewCard = ({ data }) => {
  const [isLoaded, setIsLoaded] = useState(false)

  const handleImageLoad = () => {
    setIsLoaded(true)
  }
  return data !== null ? (
    <Card className="preview_card">
      <CardBody className="invoice-padding pb-0">
        <div>
          <h2>Banner Details</h2>
          <p className="" style={{ fontSize: "18px" }}>
            Title: {data.uuid}
          </p>
          <h4>Media List</h4>
          {data.medias?.length > 0 ? (
            <ul>
              {data.medias?.map((media) => (
                <li
                  key={media.uuid}
                  style={{
                    marginBottom: "20px",
                    border: "1px solid #ddd",
                    padding: "10px",
                    listStyleType: "none"
                  }}
                >
                  <p>
                    <strong>Media UUID:</strong> {media.uuid}
                  </p>
                  <p>
                    <strong>Type:</strong> {media.type}
                  </p>
                  <p>
                    <strong>Device:</strong> {media.device}
                  </p>
                  <p>
                    <strong>File:</strong>
                    <div className="preview_card_cover my-1">
                      <div
                        className="preview_card_blur"
                        style={{ backgroundImage: `url(${media.file})` }}
                      ></div>
                      <img
                        className={`preview_card_cover_image  ${
                          isLoaded ? "is-loaded" : ""
                        }`}
                        src={`${media.file}`}
                        onLoad={handleImageLoad}
                        alt={media.uuid}
                      />
                    </div>
                  </p>
                  <p>
                    <strong>URL:</strong> {media.url}
                  </p>
                </li>
              ))}
            </ul>
          ) : (
            <p>No media associated with this campaign.</p>
          )}
        </div>
      </CardBody>
    </Card>
  ) : null
}

export default PreviewCard
