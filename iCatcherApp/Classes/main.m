//
//  main.m
//  iCatcher
//
//  Created by Nick Ludlam on 26/03/2011.
//  Copyright 2011 Berg London Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MacRuby/MacRuby.h>

int main(int argc, char *argv[])
{
  return macruby_main("rb_main.rb", argc, argv);
}
