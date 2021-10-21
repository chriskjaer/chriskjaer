/* eslint-disable @next/next/no-img-element */
import 'twin.macro'

import { ComponentProps } from 'react'

export default function Home() {
  return (
    <div tw="flex flex-col justify-center items-center min-h-screen">
      <div tw="flex justify-center items-center px-4 sm:flex-col">
        <img
          src="/chriskjaer-logo.svg"
          alt="chriskjaer logo"
          tw="block w-3 h-3 sm:(mb-3) ns:(mr-3 mt-0)"
        />

        <div tw="border-gray-300 sm:(mt-3 pt-4 border-t text-center) ns:(border-l pl-4 py-3.5 ml-3)">
          <h1 tw="font-serif text-f2.5 font-bold leading-none mb-2 sm:(mb-3 text-f3)">
            Chris Kjær Sørensen
          </h1>

          <p tw="text-f6 ns:text-f5 mb-1">
            Creative Developer, Software Engineer. <br tw="ns:hidden" /> CTO &
            Co-Founder of{' '}
            <A href="https://landfolk.com" rel="Landfolk.com">
              Landfolk
            </A>
          </p>

          <p tw="text-f6 italic nl:(text-f7 mt-3)">
            Previously: Co-Founder of{' '}
            <A href="https://gaest.com" rel="Gaest.com">
              Gaest.com
            </A>
            , ex-Airbnb.
          </p>
        </div>
      </div>

      <div tw="ns:mb-5 mt-5 space-x-3 text-f7">
        <A href="https://www.linkedin.com/in/chriskjaer/">LinkedIn</A>
        <A href="https://github.com/chriskjaer">Github</A>
      </div>
    </div>
  )
}

const A = ({ className, ...props }: ComponentProps<'a'>) => (
  // eslint-disable-next-line jsx-a11y/anchor-has-content
  <a {...props} className={className} tw="text-orange underline" />
)
