import 'tailwindcss/tailwind.css'
import '../base.global.css'

import type { AppProps } from 'next/app'
import Head from 'next/head'
import { DefaultSeo } from 'next-seo'

export default function App({ Component, pageProps }: AppProps) {
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
