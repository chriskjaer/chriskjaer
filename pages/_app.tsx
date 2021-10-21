import type { AppProps } from 'next/app'
import Head from 'next/head'
import { DefaultSeo } from 'next-seo'
import tw, { globalStyles } from 'twin.macro'

import { globalCss } from '../stitches.config'

const custom = {
  body: {
    ...tw`antialiased`,
    fontFamily:
      "avenir next, avenir, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, 'Noto Sans', sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji'",
  },
}

const styles = () => {
  globalCss(custom)()
  globalCss(globalStyles as typeof custom)()
}

export default function App({ Component, pageProps }: AppProps) {
  styles()

  return (
    <>
      <Head>
        <link rel="icon" href="/favicon.ico" />
        <link rel="icon" href="/favicon.svg" />
      </Head>
      <div>
        <DefaultSeo
          title="chriskjaer"
          description="Creative Developer, Software Engineer, Co-Founder of Gaest.com. ex-Airbnb. Now CTO & Co-Founder at Landfolk. I code stuff and make it pretty."
        />
        <Component {...pageProps} />
      </div>
    </>
  )
}
