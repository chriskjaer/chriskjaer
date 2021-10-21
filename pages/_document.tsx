// https://stitches.dev/docs/server-side-rendering

import NextDocument, {
  DocumentContext,
  Head,
  Html,
  Main,
  NextScript,
} from 'next/document'

import { getCssText } from '../stitches.config'

export default class Document extends NextDocument {
  static async getInitialProps(ctx: DocumentContext) {
    try {
      const initialProps = await NextDocument.getInitialProps(ctx)

      return {
        ...initialProps,
        styles: (
          <>
            {initialProps.styles}
            {/* Stitches CSS for SSR */}
            <style
              id="stitches"
              dangerouslySetInnerHTML={{ __html: getCssText() }}
            />
          </>
        ),
      }
    } finally {
      //
    }
  }

  render() {
    return (
      <Html lang="en">
        <Head />
        <body>
          <Main />
          <NextScript />
        </body>
      </Html>
    )
  }
}
