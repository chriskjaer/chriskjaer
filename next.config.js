const { withContentlayer } = require('next-contentlayer')

/**
 * @type {import('next/dist/next-server/server/config').NextConfig}
 **/
const config = {
  swcMinify: true,
  reactStrictMode: true,
}

module.exports = withContentlayer()(config)
