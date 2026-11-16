import crypto from 'crypto'
const key = Buffer.from(`${process.env.REACT_APP_IMGPROXY_KEY}`, 'hex')
const salt = Buffer.from(`${process.env.REACT_APP_IMGPROXY_SALT}`, 'hex')

function signUrl(url) {
    const urlPath = Buffer.from(url).toString('base64')
    const signature = crypto.createHmac('sha256', key).update(salt).update(urlPath).digest('base64')
    return `http://localhost:1055/${signature}/${urlPath}`
}

export {signUrl}
