#!/bin/bash
Encoding=UTF-8

SPACEGROUPMENU(){
	SPACEGROUPARRAY=(
        "1        = p 1          =  p 1            "
	"2        = p -1         =  -p 1           "
	"3:b      = p 1 2 1      =  p 2y           "
	"3:b      = p 2          =  p 2y           "
	"3:c      = p 1 1 2      =  p 2            "
	"3:a      = p 2 1 1      =  p 2x           "
	"4:b      = p 1 21 1     =  p 2yb          "
	"4:b      = p 1 21 1     =  p 2y1          "
	"4:b      = p 21         =  p 2yb          "
	"4:c      = p 1 1 21     =  p 2c           "
	"4:c      = p 1 1 21     =  p 21           "
	"4:a      = p 21 1 1     =  p 2xa          "
	"4:a      = p 21 1 1     =  p 2x1          "
	"5:b1     = c 1 2 1      =  c 2y           "
	"5:b1     = c 2          =  c 2y           "
	"5:b2     = a 1 2 1      =  a 2y           "
	"5:b3     = i 1 2 1      =  i 2y           "
	"5:c1     = a 1 1 2      =  a 2            "
	"5:c2     = b 1 1 2      =  b 2            "
	"5:c3     = i 1 1 2      =  i 2            "
	"5:a1     = b 2 1 1      =  b 2x           "
	"5:a2     = c 2 1 1      =  c 2x           "
	"5:a3     = i 2 1 1      =  i 2x           "
	"6:b      = p 1 m 1      =  p -2y          "
	"6:b      = p m          =  p -2y          "
	"6:c      = p 1 1 m      =  p -2           "
	"6:a      = p m 1 1      =  p -2x          "
	"7:b1     = p 1 c 1      =  p -2yc         "
	"7:b1     = p c          =  p -2yc         "
	"7:b2     = p 1 n 1      =  p -2yac        "
	"7:b2     = p n          =  p -2yac        "
	"7:b3     = p 1 a 1      =  p -2ya         "
	"7:b3     = p a          =  p -2ya         "
	"7:c1     = p 1 1 a      =  p -2a          "
	"7:c2     = p 1 1 n      =  p -2ab         "
	"7:c3     = p 1 1 b      =  p -2b          "
	"7:a1     = p b 1 1      =  p -2xb         "
	"7:a2     = p n 1 1      =  p -2xbc        "
	"7:a3     = p c 1 1      =  p -2xc         "
	"8:b1     = c 1 m 1      =  c -2y          "
	"8:b1     = c m          =  c -2y          "
	"8:b2     = a 1 m 1      =  a -2y          "
	"8:b3     = i 1 m 1      =  i -2y          "
	"8:b3     = i m          =  i -2y          "
	"8:c1     = a 1 1 m      =  a -2           "
	"8:c2     = b 1 1 m      =  b -2           "
	"8:c3     = i 1 1 m      =  i -2           "
	"8:a1     = b m 1 1      =  b -2x          "
	"8:a2     = c m 1 1      =  c -2x          "
	"8:a3     = i m 1 1      =  i -2x          "
	"9:b1     = c 1 c 1      =  c -2yc         "
	"9:b1     = c c          =  c -2yc         "
	"9:b2     = a 1 n 1      =  a -2yab        "
	"9:b3     = i 1 a 1      =  i -2ya         "
	"9:-b1    = a 1 a 1      =  a -2ya         "
	"9:-b2    = c 1 n 1      =  c -2yac        "
	"9:-b3    = i 1 c 1      =  i -2yc         "
	"9:c1     = a 1 1 a      =  a -2a          "
	"9:c2     = b 1 1 n      =  b -2ab         "
	"9:c3     = i 1 1 b      =  i -2b          "
	"9:-c1    = b 1 1 b      =  b -2b          "
	"9:-c2    = a 1 1 n      =  a -2ab         "
	"9:-c3    = i 1 1 a      =  i -2a          "
	"9:a1     = b b 1 1      =  b -2xb         "
	"9:a2     = c n 1 1      =  c -2xac        "
	"9:a3     = i c 1 1      =  i -2xc         "
	"9:-a1    = c c 1 1      =  c -2xc         "
	"9:-a2    = b n 1 1      =  b -2xab        "
	"9:-a3    = i b 1 1      =  i -2xb         "
	"10:b     = p 1 2/m 1    =  -p 2y          "
	"10:b     = p 2/m        =  -p 2y          "
	"10:c     = p 1 1 2/m    =  -p 2           "
	"10:a     = p 2/m 1 1    =  -p 2x          "
	"11:b     = p 1 21/m 1   =  -p 2yb         "
	"11:b     = p 1 21/m 1   =  -p 2y1         "
	"11:b     = p 21/m       =  -p 2yb         "
	"11:c     = p 1 1 21/m   =  -p 2c          "
	"11:c     = p 1 1 21/m   =  -p 21          "
	"11:a     = p 21/m 1 1   =  -p 2xa         "
	"11:a     = p 21/m 1 1   =  -p 2x1         "
	"12:b1    = c 1 2/m 1    =  -c 2y          "
	"12:b1    = c 2/m        =  -c 2y          "
	"12:b2    = a 1 2/m 1    =  -a 2y          "
	"12:b3    = i 1 2/m 1    =  -i 2y          "
	"12:b3    = i 2/m        =  -i 2y          "
	"12:c1    = a 1 1 2/m    =  -a 2           "
	"12:c2    = b 1 1 2/m    =  -b 2           "
	"12:c3    = i 1 1 2/m    =  -i 2           "
	"12:a1    = b 2/m 1 1    =  -b 2x          "
	"12:a2    = c 2/m 1 1    =  -c 2x          "
	"12:a3    = i 2/m 1 1    =  -i 2x          "
	"13:b1    = p 1 2/c 1    =  -p 2yc         "
	"13:b1    = p 2/c        =  -p 2yc         "
	"13:b2    = p 1 2/n 1    =  -p 2yac        "
	"13:b2    = p 2/n        =  -p 2yac        "
	"13:b3    = p 1 2/a 1    =  -p 2ya         "
	"13:b3    = p 2/a        =  -p 2ya         "
	"13:c1    = p 1 1 2/a    =  -p 2a          "
	"13:c2    = p 1 1 2/n    =  -p 2ab         "
	"13:c3    = p 1 1 2/b    =  -p 2b          "
	"13:a1    = p 2/b 1 1    =  -p 2xb         "
	"13:a2    = p 2/n 1 1    =  -p 2xbc        "
	"13:a3    = p 2/c 1 1    =  -p 2xc         "
	"14:b1    = p 1 21/c 1   =  -p 2ybc        "
	"14:b1    = p 21/c       =  -p 2ybc        "
	"14:b2    = p 1 21/n 1   =  -p 2yn         "
	"14:b2    = p 21/n       =  -p 2yn         "
	"14:b3    = p 1 21/a 1   =  -p 2yab        "
	"14:b3    = p 21/a       =  -p 2yab        "
	"14:c1    = p 1 1 21/a   =  -p 2ac         "
	"14:c2    = p 1 1 21/n   =  -p 2n          "
	"14:c3    = p 1 1 21/b   =  -p 2bc         "
	"14:a1    = p 21/b 1 1   =  -p 2xab        "
	"14:a2    = p 21/n 1 1   =  -p 2xn         "
	"14:a3    = p 21/c 1 1   =  -p 2xac        "
	"15:b1    = c 1 2/c 1    =  -c 2yc         "
	"15:b1    = c 2/c        =  -c 2yc         "
	"15:b2    = a 1 2/n 1    =  -a 2yab        "
	"15:b3    = i 1 2/a 1    =  -i 2ya         "
	"15:b3    = i 2/a        =  -i 2ya         "
	"15:-b1   = a 1 2/a 1    =  -a 2ya         "
	"15:-b2   = c 1 2/n 1    =  -c 2yac        "
	"15:-b2   = c 2/n        =  -c 2yac        "
	"15:-b3   = i 1 2/c 1    =  -i 2yc         "
	"15:-b3   = i 2/c        =  -i 2yc         "
	"15:c1    = a 1 1 2/a    =  -a 2a          "
	"15:c2    = b 1 1 2/n    =  -b 2ab         "
	"15:c3    = i 1 1 2/b    =  -i 2b          "
	"15:-c1   = b 1 1 2/b    =  -b 2b          "
	"15:-c2   = a 1 1 2/n    =  -a 2ab         "
	"15:-c3   = i 1 1 2/a    =  -i 2a          "
	"15:a1    = b 2/b 1 1    =  -b 2xb         "
	"15:a2    = c 2/n 1 1    =  -c 2xac        "
	"15:a3    = i 2/c 1 1    =  -i 2xc         "
	"15:-a1   = c 2/c 1 1    =  -c 2xc         "
	"15:-a2   = b 2/n 1 1    =  -b 2xab        "
	"15:-a3   = i 2/b 1 1    =  -i 2xb         "
	"16       = p 2 2 2      =  p 2 2          "
	"17:      = p 2 2 21     =  p 2c 2         "
	"17:      = p 2 2 21     =  p 21 2         "
	"17:cab   = p 21 2 2     =  p 2a 2a        "
	"17:bca   = p 2 21 2     =  p 2 2b         "
	"18:      = p 21 21 2    =  p 2 2ab        "
	"18:cab   = p 2 21 21    =  p 2bc 2        "
	"18:bca   = p 21 2 21    =  p 2ac 2ac      "
	"19       = p 21 21 21   =  p 2ac 2ab      "
	"20:      = c 2 2 21     =  c 2c 2         "
	"20:      = c 2 2 21     =  c 21 2         "
	"20:cab   = a 21 2 2     =  a 2a 2a        "
	"20:cab   = a 21 2 2     =  a 2a 21        "
	"20:bca   = b 2 21 2     =  b 2 2b         "
	"21:      = c 2 2 2      =  c 2 2          "
	"21:cab   = a 2 2 2      =  a 2 2          "
	"21:bca   = b 2 2 2      =  b 2 2          "
	"22       = f 2 2 2      =  f 2 2          "
	"23       = i 2 2 2      =  i 2 2          "
	"24       = i 21 21 21   =  i 2b 2c        "
	"25:      = p m m 2      =  p 2 -2         "
	"25:cab   = p 2 m m      =  p -2 2         "
	"25:bca   = p m 2 m      =  p -2 -2        "
	"26:      = p m c 21     =  p 2c -2        "
	"26:      = p m c 21     =  p 21 -2        "
	"26:ba-c  = p c m 21     =  p 2c -2c       "
	"26:ba-c  = p c m 21     =  p 21 -2c       "
	"26:cab   = p 21 m a     =  p -2a 2a       "
	"26:-cba  = p 21 a m     =  p -2 2a        "
	"26:bca   = p b 21 m     =  p -2 -2b       "
	"26:a-cb  = p m 21 b     =  p -2b -2       "
	"27:      = p c c 2      =  p 2 -2c        "
	"27:cab   = p 2 a a      =  p -2a 2        "
	"27:bca   = p b 2 b      =  p -2b -2b      "
	"28:      = p m a 2      =  p 2 -2a        "
	"28:      = p m a 2      =  p 2 -21        "
	"28:ba-c  = p b m 2      =  p 2 -2b        "
	"28:cab   = p 2 m b      =  p -2b 2        "
	"28:-cba  = p 2 c m      =  p -2c 2        "
	"28:-cba  = p 2 c m      =  p -21 2        "
	"28:bca   = p c 2 m      =  p -2c -2c      "
	"28:a-cb  = p m 2 a      =  p -2a -2a      "
	"29:      = p c a 21     =  p 2c -2ac      "
	"29:ba-c  = p b c 21     =  p 2c -2b       "
	"29:cab   = p 21 a b     =  p -2b 2a       "
	"29:-cba  = p 21 c a     =  p -2ac 2a      "
	"29:bca   = p c 21 b     =  p -2bc -2c     "
	"29:a-cb  = p b 21 a     =  p -2a -2ab     "
	"30:      = p n c 2      =  p 2 -2bc       "
	"30:ba-c  = p c n 2      =  p 2 -2ac       "
	"30:cab   = p 2 n a      =  p -2ac 2       "
	"30:-cba  = p 2 a n      =  p -2ab 2       "
	"30:bca   = p b 2 n      =  p -2ab -2ab    "
	"30:a-cb  = p n 2 b      =  p -2bc -2bc    "
	"31:      = p m n 21     =  p 2ac -2       "
	"31:ba-c  = p n m 21     =  p 2bc -2bc     "
	"31:cab   = p 21 m n     =  p -2ab 2ab     "
	"31:-cba  = p 21 n m     =  p -2 2ac       "
	"31:bca   = p n 21 m     =  p -2 -2bc      "
	"31:a-cb  = p m 21 n     =  p -2ab -2      "
	"32:      = p b a 2      =  p 2 -2ab       "
	"32:cab   = p 2 c b      =  p -2bc 2       "
	"32:bca   = p c 2 a      =  p -2ac -2ac    "
	"33:      = p n a 21     =  p 2c -2n       "
	"33:      = p n a 21     =  p 21 -2n       "
	"33:ba-c  = p b n 21     =  p 2c -2ab      "
	"33:ba-c  = p b n 21     =  p 21 -2ab      "
	"33:cab   = p 21 n b     =  p -2bc 2a      "
	"33:cab   = p 21 n b     =  p -2bc 21      "
	"33:-cba  = p 21 c n     =  p -2n 2a       "
	"33:-cba  = p 21 c n     =  p -2n 21       "
	"33:bca   = p c 21 n     =  p -2n -2ac     "
	"33:a-cb  = p n 21 a     =  p -2ac -2n     "
	"34:      = p n n 2      =  p 2 -2n        "
	"34:cab   = p 2 n n      =  p -2n 2        "
	"34:bca   = p n 2 n      =  p -2n -2n      "
	"35:      = c m m 2      =  c 2 -2         "
	"35:cab   = a 2 m m      =  a -2 2         "
	"35:bca   = b m 2 m      =  b -2 -2        "
	"36:      = c m c 21     =  c 2c -2        "
	"36:      = c m c 21     =  c 21 -2        "
	"36:ba-c  = c c m 21     =  c 2c -2c       "
	"36:ba-c  = c c m 21     =  c 21 -2c       "
	"36:cab   = a 21 m a     =  a -2a 2a       "
	"36:cab   = a 21 m a     =  a -2a 21       "
	"36:-cba  = a 21 a m     =  a -2 2a        "
	"36:-cba  = a 21 a m     =  a -2 21        "
	"36:bca   = b b 21 m     =  b -2 -2b       "
	"36:a-cb  = b m 21 b     =  b -2b -2       "
	"37:      = c c c 2      =  c 2 -2c        "
	"37:cab   = a 2 a a      =  a -2a 2        "
	"37:bca   = b b 2 b      =  b -2b -2b      "
	"38:      = a m m 2      =  a 2 -2         "
	"38:ba-c  = b m m 2      =  b 2 -2         "
	"38:cab   = b 2 m m      =  b -2 2         "
	"38:-cba  = c 2 m m      =  c -2 2         "
	"38:bca   = c m 2 m      =  c -2 -2        "
	"38:a-cb  = a m 2 m      =  a -2 -2        "
	"39:      = a b m 2      =  a 2 -2c        "
	"39:ba-c  = b m a 2      =  b 2 -2a        "
	"39:cab   = b 2 c m      =  b -2a 2        "
	"39:-cba  = c 2 m b      =  c -2a 2        "
	"39:bca   = c m 2 a      =  c -2a -2a      "
	"39:a-cb  = a c 2 m      =  a -2c -2c      "
	"40:      = a m a 2      =  a 2 -2a        "
	"40:ba-c  = b b m 2      =  b 2 -2b        "
	"40:cab   = b 2 m b      =  b -2b 2        "
	"40:-cba  = c 2 c m      =  c -2c 2        "
	"40:bca   = c c 2 m      =  c -2c -2c      "
	"40:a-cb  = a m 2 a      =  a -2a -2a      "
	"41:      = a b a 2      =  a 2 -2ab       "
	"41:ba-c  = b b a 2      =  b 2 -2ab       "
	"41:cab   = b 2 c b      =  b -2ab 2       "
	"41:-cba  = c 2 c b      =  c -2ac 2       "
	"41:bca   = c c 2 a      =  c -2ac -2ac    "
	"41:a-cb  = a c 2 a      =  a -2ab -2ab    "
	"42:      = f m m 2      =  f 2 -2         "
	"42:cab   = f 2 m m      =  f -2 2         "
	"42:bca   = f m 2 m      =  f -2 -2        "
	"43:      = f d d 2      =  f 2 -2d        "
	"43:cab   = f 2 d d      =  f -2d 2        "
	"43:bca   = f d 2 d      =  f -2d -2d      "
	"44:      = i m m 2      =  i 2 -2         "
	"44:cab   = i 2 m m      =  i -2 2         "
	"44:bca   = i m 2 m      =  i -2 -2        "
	"45:      = i b a 2      =  i 2 -2c        "
	"45:cab   = i 2 c b      =  i -2a 2        "
	"45:bca   = i c 2 a      =  i -2b -2b      "
	"46:      = i m a 2      =  i 2 -2a        "
	"46:ba-c  = i b m 2      =  i 2 -2b        "
	"46:cab   = i 2 m b      =  i -2b 2        "
	"46:-cba  = i 2 c m      =  i -2c 2        "
	"46:bca   = i c 2 m      =  i -2c -2c      "
	"46:a-cb  = i m 2 a      =  i -2a -2a      "
	"47       = p m m m      =  -p 2 2         "
	"48:1     = p n n n:1    =  p 2 2 -1n      "
	"48:2     = p n n n:2    =  -p 2ab 2bc     "
	"49:      = p c c m      =  -p 2 2c        "
	"49:cab   = p m a a      =  -p 2a 2        "
	"49:bca   = p b m b      =  -p 2b 2b       "
	"50:1     = p b a n:1    =  p 2 2 -1ab     "
	"50:2     = p b a n:2    =  -p 2ab 2b      "
	"50:1cab  = p n c b:1    =  p 2 2 -1bc     "
	"50:2cab  = p n c b:2    =  -p 2b 2bc      "
	"50:1bca  = p c n a:1    =  p 2 2 -1ac     "
	"50:2bca  = p c n a:2    =  -p 2a 2c       "
	"51:      = p m m a      =  -p 2a 2a       "
	"51:ba-c  = p m m b      =  -p 2b 2        "
	"51:cab   = p b m m      =  -p 2 2b        "
	"51:-cba  = p c m m      =  -p 2c 2c       "
	"51:bca   = p m c m      =  -p 2c 2        "
	"51:a-cb  = p m a m      =  -p 2 2a        "
	"52:      = p n n a      =  -p 2a 2bc      "
	"52:ba-c  = p n n b      =  -p 2b 2n       "
	"52:cab   = p b n n      =  -p 2n 2b       "
	"52:-cba  = p c n n      =  -p 2ab 2c      "
	"52:bca   = p n c n      =  -p 2ab 2n      "
	"52:a-cb  = p n a n      =  -p 2n 2bc      "
	"53:      = p m n a      =  -p 2ac 2       "
	"53:ba-c  = p n m b      =  -p 2bc 2bc     "
	"53:cab   = p b m n      =  -p 2ab 2ab     "
	"53:-cba  = p c n m      =  -p 2 2ac       "
	"53:bca   = p n c m      =  -p 2 2bc       "
	"53:a-cb  = p m a n      =  -p 2ab 2       "
	"54:      = p c c a      =  -p 2a 2ac      "
	"54:ba-c  = p c c b      =  -p 2b 2c       "
	"54:cab   = p b a a      =  -p 2a 2b       "
	"54:-cba  = p c a a      =  -p 2ac 2c      "
	"54:bca   = p b c b      =  -p 2bc 2b      "
	"54:a-cb  = p b a b      =  -p 2b 2ab      "
	"55:      = p b a m      =  -p 2 2ab       "
	"55:cab   = p m c b      =  -p 2bc 2       "
	"55:bca   = p c m a      =  -p 2ac 2ac     "
	"56:      = p c c n      =  -p 2ab 2ac     "
	"56:cab   = p n a a      =  -p 2ac 2bc     "
	"56:bca   = p b n b      =  -p 2bc 2ab     "
	"57:      = p b c m      =  -p 2c 2b       "
	"57:ba-c  = p c a m      =  -p 2c 2ac      "
	"57:cab   = p m c a      =  -p 2ac 2a      "
	"57:-cba  = p m a b      =  -p 2b 2a       "
	"57:bca   = p b m a      =  -p 2a 2ab      "
	"57:a-cb  = p c m b      =  -p 2bc 2c      "
	"58:      = p n n m      =  -p 2 2n        "
	"58:cab   = p m n n      =  -p 2n 2        "
	"58:bca   = p n m n      =  -p 2n 2n       "
	"59:1     = p m m n:1    =  p 2 2ab -1ab   "
	"59:2     = p m m n:2    =  -p 2ab 2a      "
	"59:1cab  = p n m m:1    =  p 2bc 2 -1bc   "
	"59:2cab  = p n m m:2    =  -p 2c 2bc      "
	"59:1bca  = p m n m:1    =  p 2ac 2ac -1ac "
	"59:2bca  = p m n m:2    =  -p 2c 2a       "
	"60:      = p b c n      =  -p 2n 2ab      "
	"60:ba-c  = p c a n      =  -p 2n 2c       "
	"60:cab   = p n c a      =  -p 2a 2n       "
	"60:-cba  = p n a b      =  -p 2bc 2n      "
	"60:bca   = p b n a      =  -p 2ac 2b      "
	"60:a-cb  = p c n b      =  -p 2b 2ac      "
	"61:      = p b c a      =  -p 2ac 2ab     "
	"61:ba-c  = p c a b      =  -p 2bc 2ac     "
	"62:      = p n m a      =  -p 2ac 2n      "
	"62:ba-c  = p m n b      =  -p 2bc 2a      "
	"62:cab   = p b n m      =  -p 2c 2ab      "
	"62:-cba  = p c m n      =  -p 2n 2ac      "
	"62:bca   = p m c n      =  -p 2n 2a       "
	"62:a-cb  = p n a m      =  -p 2c 2n       "
	"63:      = c m c m      =  -c 2c 2        "
	"63:ba-c  = c c m m      =  -c 2c 2c       "
	"63:cab   = a m m a      =  -a 2a 2a       "
	"63:-cba  = a m a m      =  -a 2 2a        "
	"63:bca   = b b m m      =  -b 2 2b        "
	"63:a-cb  = b m m b      =  -b 2b 2        "
	"64:      = c m c a      =  -c 2ac 2       "
	"64:ba-c  = c c m b      =  -c 2ac 2ac     "
	"64:cab   = a b m a      =  -a 2ab 2ab     "
	"64:-cba  = a c a m      =  -a 2 2ab       "
	"64:bca   = b b c m      =  -b 2 2ab       "
	"64:a-cb  = b m a b      =  -b 2ab 2       "
	"65:      = c m m m      =  -c 2 2         "
	"65:cab   = a m m m      =  -a 2 2         "
	"65:bca   = b m m m      =  -b 2 2         "
	"66:      = c c c m      =  -c 2 2c        "
	"66:cab   = a m a a      =  -a 2a 2        "
	"66:bca   = b b m b      =  -b 2b 2b       "
	"67:      = c m m a      =  -c 2a 2        "
	"67:ba-c  = c m m b      =  -c 2a 2a       "
	"67:cab   = a b m m      =  -a 2b 2b       "
	"67:-cba  = a c m m      =  -a 2 2c        "
	"67:bca   = b m c m      =  -b 2 2a        "
	"67:a-cb  = b m a m      =  -b 2a 2        "
	"68:1     = c c c a:1    =  c 2 2 -1ac     "
	"68:2     = c c c a:2    =  -c 2a 2ac      "
	"68:1ba-c = c c c b:1    =  c 2 2 -1ac     "
	"68:2ba-c = c c c b:2    =  -c 2a 2c       "
	"68:1cab  = a b a a:1    =  a 2 2 -1ab     "
	"68:2cab  = a b a a:2    =  -a 2a 2c       "
	"68:1-cba = a c a a:1    =  a 2 2 -1ab     "
	"68:2-cba = a c a a:2    =  -a 2ab 2b      "
	"68:1bca  = b b c b:1    =  b 2 2 -1ab     "
	"68:2bca  = b b c b:2    =  -b 2ab 2b      "
	"68:1a-cb = b b a b:1    =  b 2 2 -1ab     "
	"68:2a-cb = b b a b:2    =  -b 2b 2ab      "
	"69       = f m m m      =  -f 2 2         "
	"70:1     = f d d d:1    =  f 2 2 -1d      "
	"70:2     = f d d d:2    =  -f 2uv 2vw     "
	"71       = i m m m      =  -i 2 2         "
	"72:      = i b a m      =  -i 2 2c        "
	"72:cab   = i m c b      =  -i 2a 2        "
	"72:bca   = i c m a      =  -i 2b 2b       "
	"73:      = i b c a      =  -i 2b 2c       "
	"73:ba-c  = i c a b      =  -i 2a 2b       "
	"74:      = i m m a      =  -i 2b 2        "
	"74:ba-c  = i m m b      =  -i 2a 2a       "
	"74:cab   = i b m m      =  -i 2c 2c       "
	"74:-cba  = i c m m      =  -i 2 2b        "
	"74:bca   = i m c m      =  -i 2 2a        "
	"74:a-cb  = i m a m      =  -i 2c 2        "
	"75       = p 4          =  p 4            "
	"76:      = p 41         =  p 4w           "
	"76:      = p 41         =  p 41           "
	"77:      = p 42         =  p 4c           "
	"77:      = p 42         =  p 42           "
	"78:      = p 43         =  p 4cw          "
	"78:      = p 43         =  p 43           "
	"79       = i 4          =  i 4            "
	"80       = i 41         =  i 4bw          "
	"81       = p -4         =  p -4           "
	"82       = i -4         =  i -4           "
	"83       = p 4/m        =  -p 4           "
	"84:      = p 42/m       =  -p 4c          "
	"84:      = p 42/m       =  -p 42          "
	"85:1     = p 4/n:1      =  p 4ab -1ab     "
	"85:2     = p 4/n:2      =  -p 4a          "
	"86:1     = p 42/n:1     =  p 4n -1n       "
	"86:2     = p 42/n:2     =  -p 4bc         "
	"87       = i 4/m        =  -i 4           "
	"88:1     = i 41/a:1     =  i 4bw -1bw     "
	"88:2     = i 41/a:2     =  -i 4ad         "
	"89       = p 4 2 2      =  p 4 2          "
	"90       = p 4 21 2     =  p 4ab 2ab      "
	"91:      = p 41 2 2     =  p 4w 2c        "
	"91:      = p 41 2 2     =  p 41 2c        "
	"92       = p 41 21 2    =  p 4abw 2nw     "
	"93:      = p 42 2 2     =  p 4c 2         "
	"93:      = p 42 2 2     =  p 42 2         "
	"94       = p 42 21 2    =  p 4n 2n        "
	"95:      = p 43 2 2     =  p 4cw 2c       "
	"95:      = p 43 2 2     =  p 43 2c        "
	"96       = p 43 21 2    =  p 4nw 2abw     "
	"97       = i 4 2 2      =  i 4 2          "
	"98       = i 41 2 2     =  i 4bw 2bw      "
	"99       = p 4 m m      =  p 4 -2         "
	"100      = p 4 b m      =  p 4 -2ab       "
	"101:     = p 42 c m     =  p 4c -2c       "
	"101:     = p 42 c m     =  p 42 -2c       "
	"102      = p 42 n m     =  p 4n -2n       "
	"103      = p 4 c c      =  p 4 -2c        "
	"104      = p 4 n c      =  p 4 -2n        "
	"105:     = p 42 m c     =  p 4c -2        "
	"105:     = p 42 m c     =  p 42 -2        "
	"106:     = p 42 b c     =  p 4c -2ab      "
	"106:     = p 42 b c     =  p 42 -2ab      "
	"107      = i 4 m m      =  i 4 -2         "
	"108      = i 4 c m      =  i 4 -2c        "
	"109      = i 41 m d     =  i 4bw -2       "
	"110      = i 41 c d     =  i 4bw -2c      "
	"111      = p -4 2 m     =  p -4 2         "
	"112      = p -4 2 c     =  p -4 2c        "
	"113      = p -4 21 m    =  p -4 2ab       "
	"114      = p -4 21 c    =  p -4 2n        "
	"115      = p -4 m 2     =  p -4 -2        "
	"116      = p -4 c 2     =  p -4 -2c       "
	"117      = p -4 b 2     =  p -4 -2ab      "
	"118      = p -4 n 2     =  p -4 -2n       "
	"119      = i -4 m 2     =  i -4 -2        "
	"120      = i -4 c 2     =  i -4 -2c       "
	"121      = i -4 2 m     =  i -4 2         "
	"122      = i -4 2 d     =  i -4 2bw       "
	"123      = p 4/m m m    =  -p 4 2         "
	"124      = p 4/m c c    =  -p 4 2c        "
	"125:1    = p 4/n b m:1  =  p 4 2 -1ab     "
	"125:2    = p 4/n b m:2  =  -p 4a 2b       "
	"126:1    = p 4/n n c:1  =  p 4 2 -1n      "
	"126:2    = p 4/n n c:2  =  -p 4a 2bc      "
	"127      = p 4/m b m    =  -p 4 2ab       "
	"128      = p 4/m n c    =  -p 4 2n        "
	"129:1    = p 4/n m m:1  =  p 4ab 2ab -1ab "
	"129:2    = p 4/n m m:2  =  -p 4a 2a       "
	"130:1    = p 4/n c c:1  =  p 4ab 2n -1ab  "
	"130:2    = p 4/n c c:2  =  -p 4a 2ac      "
	"131      = p 42/m m c   =  -p 4c 2        "
	"132      = p 42/m c m   =  -p 4c 2c       "
	"133:1    = p 42/n b c:1 =  p 4n 2c -1n    "
	"133:2    = p 42/n b c:2 =  -p 4ac 2b      "
	"134:1    = p 42/n n m:1 =  p 4n 2 -1n     "
	"134:2    = p 42/n n m:2 =  -p 4ac 2bc     "
	"135:     = p 42/m b c   =  -p 4c 2ab      "
	"135:     = p 42/m b c   =  -p 42 2ab      "
	"136      = p 42/m n m   =  -p 4n 2n       "
	"137:1    = p 42/n m c:1 =  p 4n 2n -1n    "
	"137:2    = p 42/n m c:2 =  -p 4ac 2a      "
	"138:1    = p 42/n c m:1 =  p 4n 2ab -1n   "
	"138:2    = p 42/n c m:2 =  -p 4ac 2ac     "
	"139      = i 4/m m m    =  -i 4 2         "
	"140      = i 4/m c m    =  -i 4 2c        "
	"141:1    = i 41/a m d:1 =  i 4bw 2bw -1bw "
	"141:2    = i 41/a m d:2 =  -i 4bd 2       "
	"142:1    = i 41/a c d:1 =  i 4bw 2aw -1bw "
	"142:2    = i 41/a c d:2 =  -i 4bd 2c      "
	"143      = p 3          =  p 3            "
	"144      = p 31         =  p 31           "
	"145      = p 32         =  p 32           "
	"146:h    = r 3:h        =  r 3            "
	"146:r    = r 3:r        =  p 3*           "
	"147      = p -3         =  -p 3           "
	"148:h    = r -3:h       =  -r 3           "
	"148:r    = r -3:r       =  -p 3*          "
	"149      = p 3 1 2      =  p 3 2          "
	"150      = p 3 2 1      =  p 3 2""        "
	"151      = p 31 1 2     =  p 31 2 (0 0 4) "
	"152      = p 31 2 1     =  p 31 2""       "
	"153      = p 32 1 2     =  p 32 2 (0 0 2) "
	"154      = p 32 2 1     =  p 32 2""       "
	"155:h    = r 3 2:h      =  r 3 2""        "
	"155:r    = r 3 2:r      =  p 3* 2         "
	"156      = p 3 m 1      =  p 3 -2""       "
	"157      = p 3 1 m      =  p 3 -2         "
	"158      = p 3 c 1      =  p 3 -2""c      "
	"159      = p 3 1 c      =  p 3 -2c        "
	"160:h    = r 3 m:h      =  r 3 -2""       "
	"160:r    = r 3 m:r      =  p 3* -2        "
	"161:h    = r 3 c:h      =  r 3 -2""c      "
	"161:r    = r 3 c:r      =  p 3* -2n       "
	"162      = p -3 1 m     =  -p 3 2         "
	"163      = p -3 1 c     =  -p 3 2c        "
	"164      = p -3 m 1     =  -p 3 2""       "
	"165      = p -3 c 1     =  -p 3 2""c      "
	"166:h    = r -3 m:h     =  -r 3 2""       "
	"166:r    = r -3 m:r     =  -p 3* 2        "
	"167:h    = r -3 c:h     =  -r 3 2""c      "
	"167:r    = r -3 c:r     =  -p 3* 2n       "
	"168      = p 6          =  p 6            "
	"169      = p 61         =  p 61           "
	"170      = p 65         =  p 65           "
	"171      = p 62         =  p 62           "
	"172      = p 64         =  p 64           "
	"173:     = p 63         =  p 6c           "
	"173:     = p 63         =  p 63           "
	"174      = p -6         =  p -6           "
	"175      = p 6/m        =  -p 6           "
	"176:     = p 63/m       =  -p 6c          "
	"176:     = p 63/m       =  -p 63          "
	"177      = p 6 2 2      =  p 6 2          "
	"178      = p 61 2 2     =  p 61 2 (0 0 5) "
	"179      = p 65 2 2     =  p 65 2 (0 0 1) "
	"180      = p 62 2 2     =  p 62 2 (0 0 4) "
	"181      = p 64 2 2     =  p 64 2 (0 0 2) "
	"182:     = p 63 2 2     =  p 6c 2c        "
	"182:     = p 63 2 2     =  p 63 2c        "
	"183      = p 6 m m      =  p 6 -2         "
	"184      = p 6 c c      =  p 6 -2c        "
	"185:     = p 63 c m     =  p 6c -2        "
	"185:     = p 63 c m     =  p 63 -2        "
	"186:     = p 63 m c     =  p 6c -2c       "
	"186:     = p 63 m c     =  p 63 -2c       "
	"187      = p -6 m 2     =  p -6 2         "
	"188      = p -6 c 2     =  p -6c 2        "
	"189      = p -6 2 m     =  p -6 -2        "
	"190      = p -6 2 c     =  p -6c -2c      "
	"191      = p 6/m m m    =  -p 6 2         "
	"192      = p 6/m c c    =  -p 6 2c        "
	"193:     = p 63/m c m   =  -p 6c 2        "
	"193:     = p 63/m c m   =  -p 63 2        "
	"194:     = p 63/m m c   =  -p 6c 2c       "
	"194:     = p 63/m m c   =  -p 63 2c       "
	"195      = p 2 3        =  p 2 2 3        "
	"196      = f 2 3        =  f 2 2 3        "
	"197      = i 2 3        =  i 2 2 3        "
	"198      = p 21 3       =  p 2ac 2ab 3    "
	"199      = i 21 3       =  i 2b 2c 3      "
	"200      = p m -3       =  -p 2 2 3       "
	"201:1    = p n -3:1     =  p 2 2 3 -1n    "
	"201:2    = p n -3:2     =  -p 2ab 2bc 3   "
	"202      = f m -3       =  -f 2 2 3       "
	"203:1    = f d -3:1     =  f 2 2 3 -1d    "
	"203:2    = f d -3:2     =  -f 2uv 2vw 3   "
	"204      = i m -3       =  -i 2 2 3       "
	"205      = p a -3       =  -p 2ac 2ab 3   "
	"206      = i a -3       =  -i 2b 2c 3     "
	"207      = p 4 3 2      =  p 4 2 3        "
	"208      = p 42 3 2     =  p 4n 2 3       "
	"209      = f 4 3 2      =  f 4 2 3        "
	"210      = f 41 3 2     =  f 4d 2 3       "
	"211      = i 4 3 2      =  i 4 2 3        "
	"212      = p 43 3 2     =  p 4acd 2ab 3   "
	"213      = p 41 3 2     =  p 4bd 2ab 3    "
	"214      = i 41 3 2     =  i 4bd 2c 3     "
	"215      = p -4 3 m     =  p -4 2 3       "
	"216      = f -4 3 m     =  f -4 2 3       "
	"217      = i -4 3 m     =  i -4 2 3       "
	"218      = p -4 3 n     =  p -4n 2 3      "
	"219      = f -4 3 c     =  f -4a 2 3      "
	"220      = i -4 3 d     =  i -4bd 2c 3    "
	"221      = p m -3 m     =  -p 4 2 3       "
	"222:1    = p n -3 n:1   =  p 4 2 3 -1n    "
	"222:2    = p n -3 n:2   =  -p 4a 2bc 3    "
	"223      = p m -3 n     =  -p 4n 2 3      "
	"224:1    = p n -3 m:1   =  p 4n 2 3 -1n   "
	"224:2    = p n -3 m:2   =  -p 4bc 2bc 3   "
	"225      = f m -3 m     =  -f 4 2 3       "
	"226      = f m -3 c     =  -f 4a 2 3      "
	"227:1    = f d -3 m:1   =  f 4d 2 3 -1d   "
	"227:2    = f d -3 m:2   =  -f 4vw 2vw 3   "
	"228:1    = f d -3 c:1   =  f 4d 2 3 -1ad  "
	"228:2    = f d -3 c:2   =  -f 4ud 2vw 3   "
	"229      = i m -3 m     =  -i 4 2 3       "
	"230      = i a -3 d     =  -i 4bd 2c 3    ")
	
        if [[ "$SCFCALCPROG" == "elmodb" ]]; then
        	zenity --forms --title="Crystal data" --text="Enter the unit cell parameters and space group:" \
	           --add-entry="a= " \
        	   --add-entry="b= " \
        	   --add-entry="c= " \
        	   --add-entry="alpha= " \
        	   --add-entry="beta = " \
        	   --add-entry="gamma= " > crystal_data.txt
        fi
	
	zenity --entry --title "Window title" --text "${SPACEGROUPARRAY[@]}" --text "Select the space group (number = IT symbol = Hall Symbol):" > spacegroup.txt
	
}

QUEUE(){
############################################################################################################################
echo '#!/bin/sh' > lamaGOET.pbs
echo "" >> lamaGOET.pbs
echo '#PBS -V'  >> lamaGOET.pbs
if [ "$SCFCALCPROG" != "Tonto" ]; then
	echo "#PBS -l nodes=1:g09:RUN_lamaGOET:ppn=$NUMPROC" >> lamaGOET.pbs
else
	echo "#PBS -l nodes=1:RUN_lamaGOET:ppn=$NUMPROCTONTO" >> lamaGOET.pbs
fi
echo '#PBS -j eo' >> lamaGOET.pbs
echo '#PBS -q batch' >> lamaGOET.pbs
echo "#PBS -l pmem=$MEMPBS" >> lamaGOET.pbs
echo '#PBS -l walltime=999:00:00' >> lamaGOET.pbs
echo '#PBS -m bea' >> lamaGOET.pbs
echo '################ PLEASE PUT YOUR EMAIL AND JOBNAME HERE' >> lamaGOET.pbs
echo "#PBS -M $EMAIL" >> lamaGOET.pbs
echo "#PBS -N $JOBNAME" >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'echo Working directory on Server: $PBS_O_WORKDIR' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'SERVER=$PBS_O_HOST' >> lamaGOET.pbs
echo 'WORKDIR=/scratch/$USER/PBS_$PBS_JOBID' >> lamaGOET.pbs
echo 'SCP=/usr/bin/scp' >> lamaGOET.pbs
echo 'SSH=/usr/bin/ssh' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'SERVERPERMDIR=${SERVER}:$PBS_O_WORKDIR' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'mkdir /scratch/$USER/PBS_$PBS_JOBID' >> lamaGOET.pbs
echo '#PBS -o /scratch/$USER/PBS_$PBS_JOBID/$PBS_JOBNAME.o' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'echo server:		$SERVER' >> lamaGOET.pbs
echo 'echo workdir:		$WORKDIR' >> lamaGOET.pbs
echo 'echo serverpermdir:	$SERVERPERMDIR' >> lamaGOET.pbs
echo 'echo -----------------------------------------------' >> lamaGOET.pbs
echo 'echo -n "Job is running on node "; cat $PBS_NODEFILE' >> lamaGOET.pbs
echo 'echo -----------------------------------------------' >> lamaGOET.pbs
echo 'echo " "' >> lamaGOET.pbs
echo 'echo " "' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'stagein()' >> lamaGOET.pbs
echo '{' >> lamaGOET.pbs
echo '	echo "--------------------STAGEIN-------------------------"' >> lamaGOET.pbs
echo '	echo Transferring files from server to computer node' >> lamaGOET.pbs
echo '	echo Writing files in node directory ${WORKDIR}' >> lamaGOET.pbs
echo '	cd ${WORKDIR}' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
#echo '	${SCP} -r -P 2244 ${SERVERPERMDIR}/* $WORKDIR' >> lamaGOET.pbs
echo '	${SCP} -P 2244 ${SERVERPERMDIR}/* $WORKDIR' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo '	echo files in node work directory are:' >> lamaGOET.pbs
echo '	ls -l' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo '	echo " "' >> lamaGOET.pbs
echo '	echo " "' >> lamaGOET.pbs
echo '	echo "----------------STARTING PROGRAMRUN-----------------"' >> lamaGOET.pbs
echo '}' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'runprogram()' >> lamaGOET.pbs
echo '{' >> lamaGOET.pbs
echo '  export PATH=/opt/openmpi3/bin/:$PATH' >> lamaGOET.pbs
echo '  export LD_LIBRARY_PATH=/opt/openmpi3/lib:/opt/openmpi3/lib/openmpi:$LD_LIBRARY_PATH' >> lamaGOET.pbs
echo '  export LD_RUN_PATH=/opt/openmpi3/lib/openmpi:$LD_RUN_PATH' >> lamaGOET.pbs
echo "	RUN_lamaGOET  ################ <------ This is where you actually run your job!" >> lamaGOET.pbs
echo '	echo "----------------ENDING PROGRAMRUN-------------------"' >> lamaGOET.pbs
echo '	fortune' >> lamaGOET.pbs
echo '	echo " "' >> lamaGOET.pbs
echo '	echo " "' >> lamaGOET.pbs
echo '}' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'stageout()' >> lamaGOET.pbs
echo '{' >> lamaGOET.pbs
echo '	echo "-------------------STAGEOUT-------------------------"' >> lamaGOET.pbs
echo '	echo Transferring files from node to server' >> lamaGOET.pbs
echo '	echo Writing files to directory $SERVERPERMDIR' >> lamaGOET.pbs
echo '	cd ${WORKDIR}' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo '	$SCP -r -P 2244 $WORKDIR/ $SERVERPERMDIR' >> lamaGOET.pbs
echo '	if [ $? = 0 ]' >> lamaGOET.pbs
echo '	then' >> lamaGOET.pbs
echo '	        rm -r $WORKDIR /home/$USER/$PBS_JOBNAME.*' >> lamaGOET.pbs
echo '	else' >> lamaGOET.pbs
echo '	        echo "Error during copying back files, they remain on the run node"' >> lamaGOET.pbs
echo '	fi' >> lamaGOET.pbs
echo '	$SCP -P 2244 /home/$USER/$PBS_JOBNAME.* $SERVERPERMDIR' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo '	echo Final files in data directory:' >> lamaGOET.pbs
echo '	$SSH $SERVER "cd $PBS_O_WORKDIR/PBS_$PBS_JOBID; ls -l"' >> lamaGOET.pbs
echo '}' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'early()' >> lamaGOET.pbs
echo '{' >> lamaGOET.pbs
echo '	echo " "' >> lamaGOET.pbs
echo '	echo "################### WARNING: EARLY TERMINATION #########################"' >> lamaGOET.pbs
echo '	echo " "' >> lamaGOET.pbs
echo '}' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo "trap 'early; stageout' 2 9 15" >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'stagein' >> lamaGOET.pbs
echo 'runprogram' >> lamaGOET.pbs
echo 'stageout' >> lamaGOET.pbs
echo '' >> lamaGOET.pbs
echo 'exit' >> lamaGOET.pbs
#################################################### submiting to the queue ################################################
qsub lamaGOET.pbs
############################################################################################################################
}

export MAIN_DIALOG='

	<window window_position="1" title="lamaGOET: An interface for quantum crystallography">

	 <vbox scrollable="true" space-expand="true" space-fill="true" height="600" width="1000" >
	
	  <hbox homogeneous="True" >
	
	    <hbox homogeneous="True">
	     <frame>
	      <text use-markup="true" wrap="false"><label>"<span color='"'blue'"'>Welcome to the interface for quantum crystallography</span>"</label></text>
	      <pixmap>
	       <width>40</width>
	       <height>60</height>
	       <input file>/usr/local/include/llama.png</input>
	      </pixmap>
	     </frame>  
	    </hbox>
	
	  </hbox>

  	 <notebook 
		tab-labels="HAR|Advanced Settings for HAR |XCW|Elmodb advanced specific|Plots"
		xx-tab-labels="which will be shown on tabs"

		> 	  
         <vbox>       
	 <frame>

	 <hbox>

	    <text xalign="0" use-markup="true" wrap="false" space-fill="True"  space-expand="True"><label>Software for SCF calculation</label></text>
	      <radiobutton space-fill="True"  space-expand="True">
	        <label>Gaussian</label>
	        <default>true</default>
	        <action>if true echo 'SCFCALCPROG="Gaussian"'</action>  
	        <action>if true enable:MEM</action>
	        <action>if true enable:NUMPROC</action>
	        <action>if true disable:BASISSETDIR</action>
	        <action>if true enable:SCFCALC_BIN</action>
	        <action>if false disable:MEM</action>
	        <action>if false disable:NUMPROC</action>
	        <action>if false disable:SCFCALC_BIN</action>
	        <action>if false enable:BASISSETDIR</action>
	        <action>if true disable:BASISSETT</action>
	        <action>if false enable:BASISSETT</action>
	        <action>if true disable:GAMESS</action>
	        <action>if true disable:ELMOLIB</action>
	        <action>if false enable:ELMOLIB</action>
	        <action>if true enable:XHALONG</action>
	        <action>if false disable:XHALONG</action>
	        <action>if true enable:COMPLETESTRUCT</action>
	        <action>if false disable:COMPLETESTRUCT</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if false enable:USEGAMESS</action>
	        <action>if true enable:GAUSGEN</action>
	        <action>if false disable:GAUSGEN</action>
	        <action>if true enable:GAUSSREL</action>
	        <action>if false disable:GAUSSREL</action>
	        <action>if true disable:NTAIL</action>
	        <action>if false enable:NTAIL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if false enable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if false enable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if false enable:INITADP</action>
	        <action>if true enable:USEBECKE</action>
	        <action>if false disable:USEBECKE</action>
	        <action>if true enable:GAUSSEMPDISP</action>
	        <action>if false disable:GAUSSEMPDISP</action>
	        <action>if true enable:EXTRAKEY</action>
	        <action>if false disable:EXTRAKEY</action>
	        <action>if true enable:SCDIPOLES</action>
	        <action>if false disable:SCDIPOLES</action>
	      </radiobutton>
	      <radiobutton space-fill="True"  space-expand="True">
	        <label>Orca</label>
	        <default>false</default>
	        <action>if true echo 'SCFCALCPROG="Orca"'</action>
	        <action>if true enable:MEM</action>
	        <action>if true enable:NUMPROC</action>
	        <action>if true enable:SCFCALC_BIN</action>
	        <action>if true disable:BASISSETDIR</action>
	        <action>if false disable:MEM</action>
	        <action>if false disable:NUMPROC</action>
	        <action>if false disable:SCFCALC_BIN</action>
	        <action>if true disable:GAMESS</action>
	        <action>if false enable:BASISSETDIR</action>
	        <action>if true disable:BASISSETT</action>
	        <action>if false enable:BASISSETT</action>
	        <action>if true disable:ELMOLIB</action>
	        <action>if false enable:ELMOLIB</action>
	        <action>if true enable:XHALONG</action>
	        <action>if false disable:XHALONG</action>
	        <action>if true enable:COMPLETESTRUCT</action>
	        <action>if false disable:COMPLETESTRUCT</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if false enable:USEGAMESS</action>
	        <action>if true disable:GAUSGEN</action>
	        <action>if false enable:GAUSGEN</action>
	        <action>if true disable:GAUSSREL</action>
	        <action>if false enable:GAUSSREL</action>
	        <action>if true disable:NTAIL</action>
	        <action>if false enable:NTAIL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if false enable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if false enable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if false enable:INITADP</action>
	        <action>if true enable:USEBECKE</action>
	        <action>if false disable:USEBECKE</action>
	        <action>if true disable:GAUSSEMPDISP</action>
	        <action>if false enable:GAUSSEMPDISP</action>
	        <action>if true enable:EXTRAKEY</action>
	        <action>if false disable:EXTRAKEY</action>
	        <action>if true disable:SCDIPOLES</action>
	        <action>if false enable:SCDIPOLES</action>
	      </radiobutton>
	      <radiobutton space-fill="True"  space-expand="True">
	        <label>Tonto</label>
	        <default>false</default>
	        <action>if true echo 'SCFCALCPROG="Tonto"'</action>
	        <action>if true enable:BASISSETDIR</action>
	        <action>if false disable:BASISSETDIR</action>
	        <action>if true enable:USEBECKE</action>
	        <action>if false disable:USEBECKE</action>
	        <action>if true disable:BASISSETG</action>
	        <action>if false enable:BASISSETG</action>
	        <action>if true enable:BASISSETT</action>
	        <action>if false disable:BASISSETT</action>
	        <action>if true disable:GAMESS</action>
	        <action>if true disable:MEM</action>
	        <action>if true disable:NUMPROC</action>
	        <action>if true enable:NUMPROCTONTO</action>
	        <action>if false enable:MEM</action>
	        <action>if false enable:NUMPROC</action>
	        <action>if false disable:NUMPROCTONTO</action>
	        <action>if true disable:ELMOLIB</action>
	        <action>if false enable:ELMOLIB</action>
	        <action>if true enable:XHALONG</action>
	        <action>if false disable:XHALONG</action>
	        <action>if true enable:COMPLETESTRUCT</action>
	        <action>if false disable:COMPLETESTRUCT</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if false enable:USEGAMESS</action>
	        <action>if true disable:GAUSGEN</action>
	        <action>if false enable:GAUSGEN</action>
	        <action>if true disable:GAUSSREL</action>
	        <action>if false enable:GAUSSREL</action>
	        <action>if true disable:NTAIL</action>
	        <action>if false enable:NTAIL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if false enable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if false enable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if false enable:INITADP</action>
	        <action>if true disable:GAUSSEMPDISP</action>
	        <action>if false enable:GAUSSEMPDISP</action>
	        <action>if true disable:EXTRAKEY</action>
	        <action>if false enable:EXTRAKEY</action>
	        <action>if true disable:SCDIPOLES</action>
	        <action>if false enable:SCDIPOLES</action>
	      </radiobutton>
	      <radiobutton space-fill="True"  space-expand="True">
	        <label>elmodb</label>
	        <default>false</default>
	        <action>if true echo 'SCFCALCPROG="elmodb"'</action>
	        <action>if true enable:NTAIL</action>
	        <action>if false disable:NTAIL</action>
	        <action>if true disable:EXPLICITMOL</action>
	        <action>if false enable:EXPLICITMOL</action>
	        <action>if true enable:MEM</action>
	        <action>if true enable:NUMPROC</action>
	        <action>if true enable:SCFCALC_BIN</action>
	        <action>if true enable:BASISSETDIR</action>
	        <action>if false disable:MEM</action>
	        <action>if false disable:NUMPROC</action>
	        <action>if false disable:SCFCALC_BIN</action>
	        <action>if false disable:BASISSETDIR</action>
	        <action>if true disable:BASISSETT</action>
	        <action>if false enable:BASISSETT</action>
	        <action>if true disable:SCCHARGES</action>
	        <action>if false enable:SCCHARGES</action>
	        <action>if true enable:ELMOLIB</action>
	        <action>if false disable:ELMOLIB</action>
	        <action>if true disable:XHALONG</action>
	        <action>if false enable:XHALONG</action>
	        <action>if true disable:COMPLETESTRUCT</action>
	        <action>if false enable:COMPLETESTRUCT</action>
	        <action>if true enable:USEGAMESS</action>
	        <action>if false disable:USEGAMESS</action>
	        <action>if true disable:GAUSGEN</action>
	        <action>if false enable:GAUSGEN</action>
	        <action>if true disable:GAUSSREL</action>
	        <action>if false enable:GAUSSREL</action>
	        <action>if true enable:MANUALRESIDUE</action>
	        <action>if false disable:MANUALRESIDUE</action>
	        <action>if true enable:NSSBOND</action>
	        <action>if false disable:NSSBOND</action>
	        <action>if true enable:INITADP</action>
	        <action>if false disable:INITADP</action>
	        <action>if true disable:GAUSSEMPDISP</action>
	        <action>if false enable:GAUSSEMPDISP</action>
	        <action>if true disable:EXTRAKEY</action>
	        <action>if false enable:EXTRAKEY</action>
	        <action>if true disable:SCDIPOLES</action>
	        <action>if false enable:SCDIPOLES</action>
	      </radiobutton>
	      <radiobutton space-fill="True"  space-expand="True" visible="true">
	        <label>Crystal23</label>
	        <default>false</default>
	        <action>if true echo 'SCFCALCPROG="Crystal14"'</action>
	        <action>if true disable:NTAIL</action>
	        <action>if true enable:MEM</action>
	        <action>if true enable:MAXXTALCYCLE</action>
	        <action>if true enable:SUPERCON</action>
	        <action>if true enable:NUMPROC</action>
	        <action>if false disable:NUMPROC</action>
	        <action>if true enable:SCFCALC_BIN</action>
	        <action>if true disable:BASISSETDIR</action>
	        <action>if true enable:BASISSETT</action>
	        <action>if false disable:BASISSETT</action>
	        <action>if false disable:MAXXTALCYCLE</action>
	        <action>if false disable:SUPERCON</action>
	        <action>if true disable:SCCHARGES</action>
	        <action>if true disable:ELMOLIB</action>
	        <action>if true disable:XHALONG</action>
	        <action>if true disable:COMPLETESTRUCT</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if true enable:GAUSGEN</action>
	        <action>if true disable:GAUSSREL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if true disable:GAUSSEMPDISP</action>
	        <action>if true disable:EXTRAKEY</action>
	        <action>if true disable:SCDIPOLES</action>
	      </radiobutton>
	      <radiobutton space-fill="True"  space-expand="True">
	        <label>SC CC opt with Gaussian and Tonto</label>
	        <default>false</default>
	        <action>if true echo 'SCFCALCPROG="optgaussian"'</action>  
	        <action>if true enable:MEM</action>
	        <action>if true enable:NUMPROC</action>
	        <action>if true disable:BASISSETDIR</action>
	        <action>if true enable:SCFCALC_BIN</action>
	        <action>if false disable:MEM</action>
	        <action>if false disable:NUMPROC</action>
	        <action>if false disable:SCFCALC_BIN</action>
	        <action>if false enable:BASISSETDIR</action>
	        <action>if true disable:BASISSETT</action>
	        <action>if false enable:BASISSETT</action>
	        <action>if true disable:GAMESS</action>
	        <action>if true disable:ELMOLIB</action>
	        <action>if false enable:ELMOLIB</action>
	        <action>if true enable:XHALONG</action>
	        <action>if false disable:XHALONG</action>
	        <action>if true enable:COMPLETESTRUCT</action>
	        <action>if false disable:COMPLETESTRUCT</action>
	        <action>if true disable:HKL</action>
       	        <action>if false enable:HKL</action>
	        <action>if true disable:WAVE</action>
       	        <action>if false enable:WAVE</action>
	        <action>if true disable:FCUT</action>
       	        <action>if false enable:FCUT</action>
	        <action>if true disable:POSADP</action>
       	        <action>if false enable:POSADP</action>
	        <action>if true disable:POSONLY</action>
       	        <action>if false enable:POSONLY</action>
	        <action>if true disable:ADPSONLY</action>
       	        <action>if false enable:ADPSONLY</action>
	        <action>if true disable:IAMTONTO</action>
       	        <action>if false enable:IAMTONTO</action>
	        <action>if true disable:REFNOTHING</action>
       	        <action>if false enable:REFNOTHING</action>
	        <action>if true disable:REFUISO</action>
       	        <action>if false enable:REFUISO</action>
	        <action>if true disable:REFHPOS</action>
       	        <action>if false enable:REFHPOS</action>
	        <action>if true disable:REFHADP</action>
       	        <action>if false enable:REFHADP</action>
	        <action>if true disable:REFANHARM</action>
       	        <action>if false enable:REFANHARM</action>
	        <action>if true disable:DISP</action>
       	        <action>if false enable:DISP</action>
	        <action>if true enable:USEBECKE</action>
	        <action>if false disable:USEBECKE</action>
	        <action>if true disable:WRITEHEADER</action>
       	        <action>if false enable:WRITEHEADER</action>
	        <action>if true disable:USEGAMESS</action>
	        <action>if false enable:USEGAMESS</action>
	        <action>if true enable:GAUSGEN</action>
	        <action>if false disable:GAUSGEN</action>
	        <action>if true enable:GAUSSREL</action>
	        <action>if false disable:GAUSSREL</action>
	        <action>if true disable:NTAIL</action>
	        <action>if false enable:NTAIL</action>
	        <action>if true disable:MANUALRESIDUE</action>
	        <action>if false enable:MANUALRESIDUE</action>
	        <action>if true disable:NSSBOND</action>
	        <action>if false enable:NSSBOND</action>
	        <action>if true disable:INITADP</action>
	        <action>if false enable:INITADP</action>
	        <action>if true enable:GAUSSEMPDISP</action>
	        <action>if false disable:GAUSSEMPDISP</action>
	        <action>if true enable:EXTRAKEY</action>
	        <action>if false disable:EXTRAKEY</action>
	        <action>if true enable:SCDIPOLES</action>
	        <action>if false disable:SCDIPOLES</action>
	      </radiobutton>

	   </hbox>
	
          <hbox>
	    <checkbox active="false" space-fill="True" space-expand="True" sensitive="true" visible="false">
	     <label>Powder HAR</label>
	      <variable>POWDER_HAR</variable>
	        <action>if true enable:JANAEXE</action>
	        <action>if false disable:JANAEXE</action>
	        <action>if true enable:MAXPHARCYCLE</action>
	        <action>if false disable:MAXPHARCYCLE</action>
	        <action>if true enable:NSA2ACC</action>
	        <action>if false disable:NSA2ACC</action>
	    </checkbox>
	    <checkbox active="false" space-fill="True" space-expand="True" sensitive="true" visible="false">
	     <label>Calculate .tsc file with NoSpherA2</label>
	      <variable>USENOSPHERA2</variable>
	        <action>if true enable:NSA2ACC</action>
	        <action>if false disable:NSA2ACC</action>
              
	    </checkbox>

	    <checkbox active="false" space-fill="True"  space-expand="True" sensitive="false" visible="false">
	     <label>Use Gamess for calculation of overlap integrals</label>
	      <variable>USEGAMESS</variable>
	        <action>if true enable:GAMESS</action>
	        <action>if false disable:GAMESS</action>
	    </checkbox>
           </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="Tonto executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
	    <entry fs-action="file" fs-folder="./"
	           fs-title="Select the gamess_int file">
             <input>if [ ! -z $TONTO ]; then echo "$TONTO"; else (echo "tonto"); fi</input>
	     <variable>TONTO</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">TONTO</action>
	    </button>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="Jana2006 executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
	    <entry fs-action="file" fs-folder="./" sensitive="false" 
	           fs-title="Select the gamess_int file">
             <input>if [ ! -z $JANAEXE ]; then echo "$JANAEXE"; else (echo "/mnt/c/Jana2006/Jana2006.exe"); fi</input>
	     <variable>JANAEXE</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">JANAEXE</action>
	    </button>
	   </hbox>
	
	   <hseparator></hseparator>
	
	  <hbox>
	    <text label="Gaussian, Orca or elmodb executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
	    <entry fs-action="file" fs-folder="./"
	           fs-title="Select the gamess_int file">
             <input>if [ ! -z $SCFCALC_BIN ]; then echo "$SCFCALC_BIN"; else (echo "g09"); fi</input>
	     <variable>SCFCALC_BIN</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">SCFCALC_BIN</action>
	    </button>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="gamess_int executable" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
	    <entry sensitive="false" fs-action="file" fs-folder="./"
	           fs-filters="gamess_int"
	           fs-title="Select the gamess_int file">
             <input>if [ ! -z $GAMESS ]; then echo "$GAMESS"; else (echo "gamess_int"); fi</input>
	     <variable>GAMESS</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">GAMESS</action>
	    </button>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="ELMO libraries folder" has-tooltip="true" tooltip-markup="This can be a full path" ></text>
	    <entry sensitive="false" fs-action="folder" fs-folder="./"
	           fs-title="Select the ELMO library folder">
             <input>if [ ! -z $ELMOLIB ]; then echo "$ELMOLIB"; else (echo "/usr/local/bin/LIBRARIES"); fi</input>
	     <variable>ELMOLIB</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">ELMOLIB</action>
	    </button>
	   </hbox>
	
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="basis sets directory" ></text>
	    <entry sensitive="false" fs-action="folder" fs-folder="/usr/local/bin/"
	           fs-title="Select the basis_sets directory">
             <input>if [ ! -z $BASISSETDIR ]; then echo "$BASISSETDIR"; else (echo "/usr/local/bin/basis_sets"); fi</input>
	     <variable>BASISSETDIR</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">BASISSETDIR</action>
	    </button>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text use-markup="true" wrap="false"><label>Job name(one word)</label></text>
	    <entry>
             <input>if [ ! -z $JOBNAME ]; then echo "$JOBNAME"; else (echo "my_job"); fi</input>
	     <variable>JOBNAME</variable>
	    </entry>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="cif or pdb file" has-tooltip="true" tooltip-markup="ONLY use pdb file if you are using elmodb!!!" space-expand="false"></text>
	    <entry fs-action="file" fs-folder="./"
	           fs-filters="*.cif|*.pdb"
	           fs-title="Select a cif or pdb file">
             <input>if [ ! -z $CIF ]; then echo "$CIF"; fi</input>
	     <variable>CIF</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">CIF</action>
	    </button>
	
	    <checkbox active="false" has-tooltip="true" tooltip-markup="Make sure you will enter the correct charge and multiplicity" space-fill="True"  space-expand="True" sensitive="true">
	     <label>Complete molecule(s) in the cif </label>
	      <variable>COMPLETESTRUCT</variable>
	    </checkbox>
	
	   </hbox>
	
	   <hseparator></hseparator>

	   <hbox>

	    <checkbox active="false" has-tooltip="true" tooltip-markup="Make sure you will enter the correct charge and multiplicity" space-fill="True"  space-expand="True" sensitive="false">
	     <label>Load initial ADPs and precise coordinates from cif</label>
	      <variable>INITADP</variable>
	        <action>if true enable:INITADPFILE</action>
	        <action>if false disable:INITADPFILE</action>
	    </checkbox>

	    <text label="cif file" has-tooltip="true" tooltip-markup="This should have the same geometry as the pdb file!!!" space-expand="false"></text>
	    <entry fs-action="file" fs-folder="./"
	           fs-filters="*.cif"
	           fs-title="Select a cif file" sensitive="false">
	     <variable>INITADPFILE</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">INITADPFILE</action>
	    </button>
	
	
	   </hbox>

	   <hseparator></hseparator>
	
	   <hbox>
	    <text label="hkl file" space-expand="false" ></text>
	    <entry fs-action="file" fs-folder="./"
	           fs-filters="*.hkl"
	           fs-title="Select an hkl file">
             <input>if [ ! -z $HKL ]; then echo "$HKL"; fi</input>
	     <variable>HKL</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">HKL</action>
	    </button>
	
	    <checkbox active="false" has-tooltip="true" tooltip-markup="WARNING: Select one ONLY if you need a header to be written in the hkl file!" space-fill="True"  space-expand="True">
	     <label>write header </label>
	      <variable>WRITEHEADER</variable>
	      <action>if true enable:ONF</action>
	      <action>if true enable:ONF2</action>
	      <action>if false disable:ONF</action>
	      <action>if false disable:ONF2</action>
	    </checkbox>
	
	    <checkbox active="false" sensitive= "false" space-fill="True"  space-expand="True">
	     <label>on F </label>
	      <variable>ONF</variable>
	    </checkbox>
	
	    <checkbox active="false" sensitive= "false" space-fill="True"  space-expand="True">
	     <label>on F^2 </label>
	      <variable>ONF2</variable>
	    </checkbox>
	
	   </hbox>
	 
	   <hseparator></hseparator>
	
	   <hbox>
	    <text use-markup="true" wrap="TRUE" space-expand="false"><label>Wavelenght (in Angstrom)</label></text>
	    <entry>
             <input>if [ ! -z $WAVE ]; then echo "$WAVE"; else (echo "0.71073"); fi</input>
	     <variable>WAVE</variable>
	    </entry>
	
	    <text use-markup="true" wrap="TRUE" space-expand="FALSE"><label>F/sigma cutoff</label></text>
	    <entry>
             <input>if [ ! -z $FCUT ]; then echo "$FCUT"; else (echo "3"); fi</input>
	     <variable>FCUT</variable>
	    </entry>

	   </hbox>

	   <hseparator></hseparator>
	
	   <hbox> 
	    <text xalign="0" use-markup="true" wrap="false"><label>Charge</label></text>
	    <spinbutton  range-min="-20"  range-max="20" space-fill="True"  space-expand="True">
             <input>if [ ! -z $CHARGE ]; then echo "$CHARGE"; else (echo "0"); fi</input>
		<variable>CHARGE</variable>
	    </spinbutton>
	
	    <text xalign="1" use-markup="true" wrap="false"><label>Multiplicity</label></text>
	    <spinbutton  range-min="0"  range-max="20"  space-fill="True"  space-expand="True" >
             <input>if [ ! -z $MULTIPLICITY ]; then echo "$MULTIPLICITY"; else (echo "1"); fi</input>
		<variable>MULTIPLICITY</variable>
	    </spinbutton>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text xalign="0" use-markup="true" wrap="false" > <label>Method: </label></text>
	    <combobox allow-empty="true" has-tooltip="true" tooltip-markup="'"'rhf'"' - Restricted Hartree-Fock, 
	'"'rks'"' - Restricted Kohn-Sham, 
	'"'rohf'"' - Restricted open shell Hartree-Fock, 
	'"'uhf'"' - Unrestricted Hartree-Fock, 
	'"'uks'"' - Unrestricted Kohn-Sham" space-fill="True"  space-expand="True" >
	     <variable>METHOD</variable>
	     <item>rhf</item>
	     <item>rks</item>
	     <item>rohf</item>
	     <item>uhf</item>
	     <item>uks</item>
	     <item>b3lyp</item>
	    </combobox>
	
	
	    <text xalign="1" use-markup="true" wrap="false"><label>Basis set</label></text>
	    <combobox has-tooltip="true" tooltip-markup="List of Basis sets available on Tonto. Please check if the basis set you want to use contains all the elements of your structure." sensitive="false" space-fill="True"  space-expand="True">
	     <variable>BASISSETT</variable>
	     <item>STO-3G</item>
	     <item>3-21G</item>
	     <item>6-31G(d)</item>
	     <item>6-31G(d,p)</item>
	     <item>6-311++G(2d,2p)</item>
	     <item>6-311G(d,p)</item>
	     <item>ahlrichs-polarization</item>
	     <item>aug-cc-pVDZ</item>
	     <item>aug-cc-pVQZ</item>
	     <item>aug-cc-pVTZ</item>
	     <item>cc-pVDZ</item>
	     <item>cc-pVQZ</item>
	     <item>cc-pVTZ</item>
	     <item>Clementi-Roetti</item>
	     <item>Coppens</item>
	     <item>def2-SVP</item>
	     <item>def2-SV(P)</item>
	     <item>def2-TZVP</item>
	     <item>def2-TZVPP</item>
	     <item>DZP</item>
	     <item>DZP-DKH</item>
	     <item>pVDZ-Ahlrichs</item>
	     <item>Sadlej+</item>
	     <item>Sadlej-PVTZ</item>
	     <item>Spackman-DZP+</item>
	     <item>Thakkar</item>
	     <item>TZP-DKH</item>
	     <item>vanLenthe-Baerends</item>
	     <item>VTZ-Ahlrichs</item>
	    </combobox>
	
	   </hbox>

	   <hseparator></hseparator>
	
	   <hbox>
	
	    <text><label>Enter manually for Gaussian, Orca or elmodb!</label> </text>
	    <entry tooltip-text="Use the correct Gaussian or Orca or Tonto format" sensitive="true">
             <input>if [ ! -z $BASISSETG ]; then echo "$BASISSETG"; else (echo "STO-3G"); fi</input>
	     <variable>BASISSETG</variable>
	    </entry>
	
	   </hbox>

	   <hseparator></hseparator>

	   <hbox>

	    <checkbox active="false" space-fill="True"  space-expand="True">
	     <label>Input external basis set manualy </label>
	      <variable>GAUSGEN</variable>
	      <action>if true disable:BASISSETG</action>
	      <action>if false enable:BASISSETG</action>
	    </checkbox>

	   </hbox>

	   <hseparator></hseparator>

	   <hbox>
	
	    <checkbox active="false" space-fill="True"  space-expand="True">
	     <label>Use Grimme dispersion (gd3bj) </label>
	      <variable>GAUSSEMPDISP</variable>
	    </checkbox>

	    <checkbox active="false" space-fill="True"  space-expand="True">
	     <label>Use relativistic method </label>
	      <variable>GAUSSREL</variable>
	    </checkbox>

	   </hbox>

	   <hseparator></hseparator>

	   <hbox>
	
	    <text><label>Extra Gaussian keywords</label> </text>
	    <entry tooltip-text="Use the correct Gaussian format" sensitive="true">
             <input>if [ ! -z $EXTRAKEY ]; then echo "$EXTRAKEY"; fi</input>
	     <variable>EXTRAKEY</variable>
	    </entry>
	
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	
	    <checkbox>
	     <label>Use SC cluster charges? </label>
	      <variable>SCCHARGES</variable>
	      <action>if true enable:SCCRADIUS</action>
	      <action>if false disable:SCCRADIUS</action>
	      <action>if true enable:DEFRAG</action>
	      <action>if false disable:DEFRAG</action>
	    </checkbox>
	
	    <text use-markup="true" wrap="false" ><label>SC Cluster charges radius</label></text>
	    <entry has-tooltip="true" tooltip-markup="in Angstrom" sensitive="false">
             <input>if [ ! -z $SCCRADIUS ]; then echo "$SCCRADIUS"; else (echo "8"); fi</input>
	     <variable>SCCRADIUS</variable>
	    </entry>
	
	    <checkbox sensitive="false">
	     <label>Complete molecules </label>
	     <default>false</default>
	      <variable>DEFRAG</variable>
	    </checkbox>

	    <checkbox sensitive="true">
	     <label>Use dipoles </label>
	     <default>false</default>
	      <variable>SCDIPOLES</variable>
	    </checkbox>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	
	    <checkbox>
	     <label>Use explicit cluster of molecules? </label>
	      <variable>EXPLICITMOL</variable>
	      <action>if true enable:EXPLRADIUS</action>
	      <action>if false disable:EXPLRADIUS</action>
	      <action>if true enable:DEFRAGEXPL</action>
	      <action>if false disable:DEFRAGEXPL</action>
	    </checkbox>
	
	    <text use-markup="true" wrap="false" ><label>within radius</label></text>
	    <entry has-tooltip="true" tooltip-markup="in Angstrom" sensitive="false">
             <input>if [ ! -z $EXPLRADIUS ]; then echo "$EXPLRADIUS"; else (echo "3"); fi</input>
	     <variable>EXPLRADIUS</variable>
	    </entry>
	
	    <checkbox sensitive="false">
	     <label>Complete molecules </label>
	     <default>false</default>
	      <variable>DEFRAGEXPL</variable>
	    </checkbox>
	   </hbox>

	   <hseparator></hseparator>
		
	   <hbox>
	    <text xalign="0" use-markup="true" wrap="false" space-fill="True"  space-expand="True"><label>Refinement options (all atom types): </label></text>
	    <radiobutton>
	        <label>positions and ADPs</label>
	        <default>true</default>
	        <variable>POSADP</variable>
	    </radiobutton>
	    <radiobutton>
	        <label>positions only</label>
	        <variable>POSONLY</variable>
	        <action>if true disable:REFHADP</action>
	        <action>if false enable:REFHADP</action>
	        <action>if true disable:HADP</action>
	        <action>if false enable:HADP</action>
	    </radiobutton>
	    <radiobutton>
	        <label>ADPs only</label>
	        <variable>ADPSONLY</variable>
	        <action>if true disable:REFHPOS</action>
	        <action>if false enable:REFHPOS</action>
	    </radiobutton>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <checkbox sensitive="true" space-fill="True"  space-expand="True">
	     <label>Start refinement with a Tonto IAM </label>
	      <variable>IAMTONTO</variable>
	      <action>if true disable:XHALONG</action>
	      <action>if false enable:XHALONG</action>
	      <action>if true enable:ONLYIAMTONTO</action>
	      <action>if false disable:ONLYIAMTONTO</action>
	    </checkbox>
           
	    <checkbox sensitive="false" space-fill="True"  space-expand="True">
	     <label>Only Perform the Tonto IAM </label>
	      <variable>ONLYIAMTONTO</variable>
	      <action>if true disable:XHALONG</action>
	      <action>if false enable:XHALONG</action>
	    </checkbox>
	   </hbox>

	   <hseparator></hseparator>

           <hbox>
	    <checkbox active="false" space-fill="True"  space-expand="True">
	        <label>Refine nothing for atoms:</label>
	        <default>true</default>
	        <variable>REFNOTHING</variable>
	        <action>if true enable:ATOMLIST</action>
	        <action>if false disable:ATOMLIST</action>
	    </checkbox>
	    <text use-markup="true" wrap="false" ><label>atom labels:</label></text>
	    <entry sensitive="false">
             <input>if [ ! -z $ATOMLIST ]; then echo "$ATOMLIST"; fi</input>
	     <variable>ATOMLIST</variable>
	    </entry>
           </hbox>
	
	   <hseparator></hseparator>

           <hbox>
	    <checkbox active="false" space-fill="True"  space-expand="True">
	        <label>Refine these atoms isotropically:</label>
	        <default>true</default>
	        <variable>REFUISO</variable>
	        <action>if true enable:ATOMUISOLIST</action>
	        <action>if false disable:ATOMUISOLIST</action>
	    </checkbox>
	    <text use-markup="true" wrap="false" ><label>atom labels:</label></text>
	    <entry sensitive="false">
	     <variable>ATOMUISOLIST</variable>
	    </entry>
           </hbox>
	
	   <hseparator></hseparator>

	   <hbox>
	
	    <checkbox active="true" space-fill="True"  space-expand="True">
	     <label>Refine H positions ?</label>
	      <variable>REFHPOS</variable>
	      <action>if true disable:XHALONG</action>
	      <action>if false enable:XHALONG</action>
	    </checkbox>
	
	    <checkbox active="true">
	     <label>Refine_H_ADPs</label>
	      <variable>REFHADP</variable>
	      <action>if true enable:HADP</action>
	      <action>if false disable:HADP</action>
	    </checkbox>
	
	    <text xalign="0" use-markup="true" wrap="false"><label>Refine H atom isotropically?</label></text>
	    <combobox>
	      <variable>HADP</variable>
	      <item>no</item>
	      <item>yes</item>
	    </combobox>
	   </hbox>

	   <hseparator></hseparator>

	   <hbox>

	    <checkbox sensitive="true" space-fill="True"  space-expand="True">
	     <label>Refine anharmonic ADPs</label>
	      <variable>REFANHARM</variable>
	      <action>if true enable:ANHARMATOMS</action>
	      <action>if false disable:ANHARMATOMS</action>
	      <action>if true enable:THIRDORD</action>
	      <action>if false disable:THIRDORD</action>
	      <action>if true enable:FOURTHORD</action>
	      <action>if false disable:FOURTHORD</action>
	    </checkbox>
	
	    <text use-markup="true" wrap="false"  ><label>Atom labels</label></text>
	    <entry has-tooltip="true" tooltip-markup="as in the cif" sensitive="false">
             <input>if [ ! -z $ANHARMATOMS ]; then echo "$ANHARMATOMS"; fi</input>
	     <variable>ANHARMATOMS</variable>
	    </entry>
	
	    <checkbox sensitive="false">
	     <label>3rd Order</label>
	     <default>false</default>
	      <variable>THIRDORD</variable>
	    </checkbox>

	    <checkbox sensitive="false">
	     <label>4rd Order</label>
	     <default>false</default>
	      <variable>FOURTHORD</variable>
	    </checkbox>
	   </hbox>
	
	
	   <hseparator></hseparator>
	
	   <hbox>
	
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
	     <label>Elongate X-H bond lengths ?</label>
	     <variable>XHALONG</variable>
	     <default>false</default>
	     <action>if true enable:BHBOND</action>
	     <action>if false disable:BHBOND</action>
	     <action>if true enable:CHBOND</action>
	     <action>if false disable:CHBOND</action>
	     <action>if true enable:NHBOND</action>
	     <action>if false disable:NHBOND</action>
	     <action>if true enable:OHBOND</action>
	     <action>if false disable:OHBOND</action>
	    </checkbox>
	
	    <text xalign="1" use-markup="true" wrap="false"><label>if yes, enter new bond lengths below (leave empty for unchanged)</label></text>
	   </hbox>
	
	   <hbox>
	    <text xalign="0" use-markup="true" wrap="false"><label>B-H:</label></text>
	    <entry sensitive="false">
             <input>if [ ! -z $BHBOND ]; then echo "$BHBOND"; else (echo "1.190"); fi</input>
	     <variable>BHBOND</variable>
	      <visible>disabled</visible>
	    </entry>
	    <text xalign="0" use-markup="true" wrap="false"><label>C-H:</label></text>
	    <entry sensitive="false">
             <input>if [ ! -z $CHBOND ]; then echo "$CHBOND"; else (echo "1.083"); fi</input>
	     <variable>CHBOND</variable>
	    </entry>
	   </hbox>
	
	   <hbox>
	    <text xalign="0" use-markup="true" wrap="false"><label>N-H:</label></text>
	    <entry sensitive="false">
             <input>if [ ! -z $NHBOND ]; then echo "$NHBOND"; else (echo "1.009"); fi</input>
	     <variable>NHBOND</variable>
	    </entry>
	    <text xalign="0" use-markup="true" wrap="false"><label>O-H:</label></text>
	    <entry sensitive="false">
             <input>if [ ! -z $OHBOND ]; then echo "$OHBOND"; else (echo "0.983"); fi</input>
	     <variable>OHBOND</variable>
	    </entry>
	
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text xalign="0" use-markup="true" wrap="false"><label>Apply dispersion corrections?</label></text>
	    <combobox has-tooltip="true" tooltip-markup="Enter the '"f'"' and '"f''"' values in popup window after pressing '"'OK'"'" space-fill="True"  space-expand="True">
	      <variable>DISP</variable>
	      <item>no</item>
	      <item>yes</item>
	    </combobox>
	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox> 
	    <text xalign="0" use-markup="true" wrap="false"justify="1"><label>Number of processors available for the Gaussian or Orca job</label></text>
	    <spinbutton  range-min="1"  range-max="100" space-fill="True"  space-expand="True">
             <input>if [ ! -z $NUMPROC ]; then echo "$NUMPROC"; else (echo "1"); fi</input>
		<variable>NUMPROC</variable>
	    </spinbutton>


	    <text xalign="0" use-markup="true"
            wrap="false"justify="1"><label>Number of processors available for Tonto</label></text>
            <spinbutton  range-min="1"  range-max="100" space-fill="True"  space-expand="True">
             <input>if [ ! -z $NUMPROCTONTO ]; then echo "$NUMPROCTONTO"; else (echo "1"); fi</input>
		<variable>NUMPROCTONTO</variable>
	    </spinbutton>

	   </hbox>
	
	   <hseparator></hseparator>
	
	   <hbox>
	    <text xalign="0" use-markup="true" has-tooltip="true" tooltip-markup="(including the unit mb or gb. For elmodb only in mb without unit!)" wrap="false"><label>Memory available for the Gaussian, Orca or elmodb job</label></text>
	    <entry>
             <input>if [ ! -z $MEM ]; then echo "$MEM"; else (echo "1gb"); fi</input>
	     <variable>MEM</variable>
	    </entry>
	   </hbox>
	
	   <hseparator></hseparator>

	   <hbox>
	    <text xalign="0" use-markup="true" has-tooltip="true" tooltip-markup="(including the unit mb or gb.)" wrap="false"><label>Memory available for the PBS script</label></text>
	    <entry>
	     <default>1gb</default>
	     <variable>MEMPBS</variable>
	    </entry>
	   </hbox>
	
	   <hseparator></hseparator>


	   <hbox>
	    <text xalign="0" use-markup="true" wrap="false"><label>Your email:</label></text>
	    <entry sensitive="true">
	     <variable>EMAIL</variable>
	    </entry>
	   </hbox>

	  </frame>
         </vbox>
         <vbox>
 
	  <frame>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Conv. tol. for shift on esd</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
             <input>if [ ! -z $CONVTOL ]; then echo "$CONVTOL"; else (echo "0.010000"); fi</input>
	     <variable>CONVTOL</variable>
	    </entry>
	
	   </hbox>
	   </hbox>

	   <hseparator></hseparator>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false"
            space-expand="FALSE" space-fill="false"><label>Conv. tol. for DE (between two consec. cycles)</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
             <input>if [ ! -z $CONVTOLE ]; then echo "$CONVTOLE"; else (echo "0.000001"); fi</input>
	     <variable>CONVTOLE</variable>
	    </entry>
	
	   </hbox>
	   </hbox>

	   <hseparator></hseparator>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Max. number of iteration (for each L.S. cycle):</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
             <input>if [ ! -z $MAXLSCYCLE ]; then echo "$MAXLSCYCLE"; else (echo "30"); fi</input>
	     <variable>MAXLSCYCLE</variable>
	    </entry>
	
	   </hbox>
	   </hbox>

	   <hseparator></hseparator>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Max. number of cycles for Crystal23 SCF calculation:</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
             <input>if [ ! -z $MAXXTALCYCLE ]; then echo "$MAXXTALCYCLE"; fi</input>
	     <variable>MAXXTALCYCLE</variable>
	    </entry>
	        
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
	     <label>Force conventional cell on Crystal23</label>
	     <variable>SUPERCON</variable>
	     <default>false</default>
	    </checkbox>

	   </hbox>
	   </hbox>

	   <hbox space-expand="false" space-fill="false">
           
	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Shrink values for Crystal23:</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
             <input>if [ ! -z $SHRINKA ]; then echo "$SHRINKA"; else (echo "6"); fi</input>
	     <variable>SHRINKA</variable>
	    </entry>
	    <entry space-expand="true">
             <input>if [ ! -z $SHRINKB ]; then echo "$SHRINKB"; else (echo "6"); fi</input>
	     <variable>SHRINKB</variable>
	    </entry>

	   </hbox>
	   </hbox>

	   <hseparator></hseparator>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false"
            space-expand="FALSE" space-fill="false"><label>Max. number of Powder HAR iteration (for each L.S. cycle):</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true" sensitive="false">
             <input>if [ ! -z $MAXPHARCYCLE ]; then echo "$MAXPHARCYCLE"; else (echo "10"); fi</input>
	     <variable>MAXPHARCYCLE</variable>
	    </entry>
	
	   </hbox>
	   </hbox>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Accuracy for NoSpherA2 tsc calculation:</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true" sensitive="false">
             <input>if [ ! -z $NSA2ACC ]; then echo "$NSA2ACC"; else (echo "2"); fi</input>
	     <variable>NSA2ACC</variable>
	    </entry>
	
	   </hbox>

	   </hbox>

	   <hseparator></hseparator>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Max. L.S. cycles (use if stuck at conv.):</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
             <input>if [ ! -z $MAXCYCLE ]; then echo "$MAXCYCLE"; else (echo "30"); fi</input>
	     <variable>MAXCYCLE</variable>
	    </entry>
	
	   </hbox>
	   </hbox>

	   <hbox space-expand="false" space-fill="false">

	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>The minimum value for correlation matrix elements to be printed:</label></text>
	   <hbox space-expand="true" space-fill="true">
	    <entry space-expand="true">
             <input>if [ ! -z $MINCORCOEF ]; then echo "$MINCORCOEF"; else (echo ""); fi</input>
	     <variable>MINCORCOEF</variable>
	    </entry>
	
	   </hbox>
	   </hbox>

	   <hseparator></hseparator>

	   <hbox>
	    <checkbox sensitive="false" space-fill="True"  space-expand="True">
	     <label>Use becke grid? </label>
	      <variable>USEBECKE</variable>
	      <action>if true enable:ACCURACY</action>
	      <action>if true enable:BECKEPRUNINGSCHEME</action>
	      <action>if false disable:ACCURACY</action>
	      <action>if false disable:BECKEPRUNINGSCHEME</action>
	    </checkbox>
	
	    <text use-markup="true" wrap="false"><label>Becke grid accuracy</label></text>
	    <combobox has-tooltip="true" tooltip-markup="FOR TONTO SCF ONLY: 
	'"'very_low'"' to '"'very_high'"' are Treutler-Ahlrichs settings, 
	'"'extreme'"' and '"'best'"' are better than the Mura-Knowles settings. 
	The '"'low'"' value is the one comparable to Gaussian." sensitive="false">
	      <variable>ACCURACY</variable>
	      <item>very_low</item>
	      <item>low</item>
	      <item>medium</item>
	      <item>high</item>
	      <item>very_high</item>
	      <item>extreme</item>
	      <item>best</item>
	
	    </combobox>
	   </hbox>
	
	
	   <hbox>
	    <text use-markup="true" wrap="false"><label>Becke grid prunning scheme</label></text>
	    <combobox sensitive="false" has-tooltip="true" tooltip-markup="FOR TONTO SCF ONLY: 
	Set the angular pruning scheme for lebedev_grid given a radial point '"'i'"' out of a set of '"'nr'"' radial points arranged in increasing order.">
	      <variable>BECKEPRUNINGSCHEME</variable>
	      <item>none</item>
	      <item>jayatilaka0</item>
	      <item>jayatilaka1</item>
	      <item>jayatilaka2</item>
	      <item>treutler_ahlrichs</item>
	    </combobox>
	   </hbox>
	
	
	   <hseparator></hseparator>

	  </frame>
         </vbox>

	 <vbox visible="true">
	  <frame>

	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" >
  	     <label>Perform only XCW (based on input geometry, no HAR) or</label>
	     <variable>XCWONLY</variable>		
	     <default>false</default>
	      <action>if true enable:METHODXCW</action>
	      <action>if true enable:BASISSETTXCW</action>
	      <action>if false disable:METHODXCW</action>
	      <action>if false disable:BASISSETTXCW</action>
	      <action>if true enable:LAMBDAINITIAL</action>
	      <action>if true enable:LAMBDASTEP</action>
	      <action>if true enable:LAMBDAMAX</action>
	      <action>if false disable:LAMBDAINITIAL</action>
	      <action>if false disable:LAMBDASTEP</action>
	      <action>if false disable:LAMBDAMAX</action>
	      <action>if true enable:BASISSETDIRXCW</action>
	      <action>if false disable:BASISSETDIRXCW</action>
	      <action>if true enable:SCCHARGESXCW</action>
	      <action>if false disable:SCCHARGESXCW</action>
	    </checkbox>

	    <checkbox  active="false" sensitive="true" space-fill="True"  space-expand="True" >
  	     <label>Perform XWR (HAR + XCW) job</label>
	     <variable>XWR</variable>		
	     <default>false</default>
	      <action>if true enable:METHODXCW</action>
	      <action>if true enable:BASISSETTXCW</action>
	      <action>if false disable:METHODXCW</action>
	      <action>if false disable:BASISSETTXCW</action>
	      <action>if true enable:LAMBDAINITIAL</action>
	      <action>if true enable:LAMBDASTEP</action>
	      <action>if true enable:LAMBDAMAX</action>
	      <action>if false disable:LAMBDAINITIAL</action>
	      <action>if false disable:LAMBDASTEP</action>
	      <action>if false disable:LAMBDAMAX</action>
	      <action>if true enable:BASISSETDIRXCW</action>
	      <action>if false disable:BASISSETDIRXCW</action>
	      <action>if true enable:SCCHARGESXCW</action>
	      <action>if false disable:SCCHARGESXCW</action>
	    </checkbox>
	   </hbox> 

	   <hbox>
	    <text label="basis sets directory" ></text>
	    <entry sensitive="false" fs-action="folder" fs-folder="/usr/local/bin/"
	           fs-title="Select the basis_sets directory">
             <input>if [ ! -z $BASISSETDIRXCW ]; then echo "$BASISSETDIRXCW"; else (echo "/usr/local/bin/basis_sets"); fi</input>
	     <variable>BASISSETDIRXCW</variable>
	    </entry>
	    <button>
	     <input file stock="gtk-open"></input>
	     <action type="fileselect">BASISSETDIRXCW</action>
	    </button>
	   </hbox>

	   <hbox>
	    <text xalign="0" use-markup="true" wrap="false" > <label>Method: </label></text>
	    <combobox sensitive="false" allow-empty="true" has-tooltip="true" tooltip-markup="'"'rhf'"' - Restricted Hartree-Fock, 
	'"'rks'"' - Restricted Kohn-Sham, 
	'"'rohf'"' - Restricted open shell Hartree-Fock, 
	'"'uhf'"' - Unrestricted Hartree-Fock, 
	'"'uks'"' - Unrestricted Kohn-Sham" space-fill="True"  space-expand="True" >
	     <variable>METHODXCW</variable>
	     <item>rhf</item>
	     <item>rks</item>
	     <item>rohf</item>
	     <item>uhf</item>
	     <item>uks</item>
	     <item>b3lyp</item>
	    </combobox>
	
	
	    <text xalign="1" use-markup="true" wrap="false"><label>Basis set</label></text>
	    <combobox has-tooltip="true" tooltip-markup="List of Basis sets available on Tonto. Please check if the basis set you want to use contains all the elements of your structure." sensitive="false" space-fill="True"  space-expand="True">
	     <variable>BASISSETTXCW</variable>
	     <item>STO-3G</item>
	     <item>3-21G</item>
	     <item>6-31G(d)</item>
	     <item>6-31G(d,p)</item>
	     <item>6-311++G(2d,2p)</item>
	     <item>6-311G(d,p)</item>
	     <item>ahlrichs-polarization</item>
	     <item>aug-cc-pVDZ</item>
	     <item>aug-cc-pVQZ</item>
	     <item>aug-cc-pVTZ</item>
	     <item>cc-pVDZ</item>
	     <item>cc-pVQZ</item>
	     <item>cc-pVTZ</item>
	     <item>Clementi-Roetti</item>
	     <item>Coppens</item>
	     <item>def2-SVP</item>
	     <item>def2-SV(P)</item>
	     <item>def2-TZVP</item>
	     <item>def2-TZVPP</item>
	     <item>DZP</item>
	     <item>DZP-DKH</item>
	     <item>pVDZ-Ahlrichs</item>
	     <item>Sadlej+</item>
	     <item>Sadlej-PVTZ</item>
	     <item>Spackman-DZP+</item>
	     <item>Thakkar</item>
	     <item>TZP-DKH</item>
	     <item>vanLenthe-Baerends</item>
	     <item>VTZ-Ahlrichs</item>
	    </combobox>
	
	   </hbox>

	   <hbox>
	
	    <checkbox sensitive="false">
	     <label>Use SC cluster charges? </label>
	      <variable>SCCHARGESXCW</variable>
	      <action>if true enable:SCCRADIUSXCW</action>
	      <action>if false disable:SCCRADIUSXCW</action>
	      <action>if true enable:DEFRAGXCW</action>
	      <action>if false disable:DEFRAGXCW</action>
	    </checkbox>
	
	    <text use-markup="true" wrap="false" ><label>SC Cluster charges radius</label></text>
	    <entry has-tooltip="true" tooltip-markup="in Angstrom" sensitive="false">
             <input>if [ ! -z $SCCRADIUSXCW ]; then echo "$SCCRADIUSXCW"; else (echo "8"); fi</input>
	     <variable>SCCRADIUSXCW</variable>
	    </entry>
	
	    <checkbox sensitive="false">
	     <label>Complete molecules </label>
	     <default>false</default>
	      <variable>DEFRAGXCW</variable>
	    </checkbox>
	   </hbox>

   	  <hbox> 
	    <text xalign="0" use-markup="true" wrap="false"justify="1"><label>Enter initial lambda value:</label></text>
	    <entry  range-min="1"  range-max="100" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $LAMBDA ]; then echo "$LAMBDA"; else (echo "0"); fi</input>
		<variable>LAMBDAINITIAL</variable>
	    </entry>
	   </hbox><

   	  <hbox> 
	    <text xalign="0" use-markup="true" wrap="false"justify="1"><label>Enter lambda step size value:</label></text>
	    <entry  range-min="1"  range-max="100" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $LAMBDA ]; then echo "$LAMBDA"; else (echo "0.1"); fi</input>
		<variable>LAMBDASTEP</variable>
	    </entry>
	   </hbox><

   	  <hbox> 
	    <text xalign="0" use-markup="true" wrap="false"justify="1"><label>Enter lambda max value:</label></text>
	    <entry  range-min="1"  range-max="100" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $LAMBDA ]; then echo "$LAMBDA"; else (echo "1"); fi</input>
		<variable>LAMBDAMAX</variable>
	    </entry>
	   </hbox><

	  </frame>
	 </vbox>

	 <vbox visible="true">
	  <frame>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Number of dissulfide bonds:</label></text>
           <spinbutton  range-min="0"  range-max="1000" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $NSSBOND ]; then echo "$NSSBOND"; else (echo "0"); fi</input>
	    <variable>NSSBOND</variable>
	    <action condition="command_is_true( [ $NSSBOND -gt 0 ] && echo true )">enable:SSBONDATOMS</action>
	    <action condition="command_is_false( [ $NSSBOND -eq 0 ] && echo false )">disable:SSBONDATOMS</action>
	   </spinbutton>
	   </hbox>

	   <hbox>
	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Enter the residue information manually:</label></text>
 	    <edit space-expand="true" space-fill="true" sensitive="false">
	    <action condition="command_is_true( [ $NSSBOND -gt 0 ] && echo true )">enable:SSBONDATOMS</action>
	    <action condition="command_is_false( [ $NSSBOND -eq 0 ] && echo false )">disable:SSBONDATOMS</action>
             <input file>DISSBONDS</input>
             <variable>SSBONDATOMS</variable>
      	     <width>350</width><height>150</height>
             <action  condition="file_is_false(ntail.txt)">touch ntail.txt</action>
    	    </edit>
	   </hbox>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Enter number of tailor made residues:</label></text>
           <spinbutton  range-min="0"  range-max="100" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $NTAIL ]; then echo "$NTAIL"; else (echo "0"); fi</input>
	    <variable>NTAIL</variable>
	      <action condition="command_is_true( [ $NTAIL -gt 0 ] && echo true )">enable:ATAIL</action>
	      <action condition="command_is_false( [ $NTAIL -eq 0 ] && echo false )">disable:ATAIL</action>
	      <action condition="command_is_true( [ $FRTAIL -gt 0 ] && echo true )">enable:FRTAIL</action>
	      <action condition="command_is_false( [ $FRTAIL -eq 0 ] && echo false )">disable:FRTAIL</action>
	   </spinbutton>
	   </hbox>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Enter maximum number of atoms in tailor made residues:</label></text>
           <spinbutton  range-min="0"  range-max="1000" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $ATAIL ]; then echo "$ATAIL"; else (echo "100"); fi</input>
	    <variable>ATAIL</variable>
	   </spinbutton>
	   </hbox>

   	  <hbox> 
           <text xalign="0" use-markup="true" wrap="false" justify="1"><label>Enter maximum number of fragments in tailor made residues:</label></text>
           <spinbutton  range-min="0"  range-max="1000" space-fill="True"  space-expand="True" sensitive="false">
             <input>if [ ! -z $FRTAIL ]; then echo "$FRTAIL"; else (echo "200"); fi</input>
	    <variable>FRTAIL</variable>
	   </spinbutton>
	   </hbox>

	   <hbox>
	    <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Enter the residue information manually:</label></text>
 	    <edit space-expand="true" space-fill="true" sensitive="false">
             <input file> TAILORED</input>
             <variable>MANUALRESIDUE</variable>
      	     <width>350</width><height>350</height>
             <action  condition="file_is_false(ntail.txt)">touch ntail.txt</action>
    	    </edit>
	   </hbox>
 
	  </frame>
	 </vbox>

	 <vbox visible="true">
	  <frame>

	   <hbox>
	
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" >
	     <label>Only plot properties from Tonto restricted files</label>
	     <variable>PLOT_TONTO</variable>		
	     <default>false</default>
	     <action>if true enable:DEFDEN</action>
	     <action>if true enable:DFTXCPOT</action>
	     <action>if true enable:DENS</action>
	     <action>if true enable:LAPL</action>
	     <action>if true enable:NEGLAPL</action>
	     <action>if true enable:PROMOL</action>
	     <action>if true enable:RESDENS</action>
	     <action>if false disable:DEFDEN</action>
	     <action>if false disable:DFTXCPOT</action>
	     <action>if false disable:DENS</action>
	     <action>if false disable:LAPL</action>
	     <action>if false disable:NEGLAPL</action>
	     <action>if false disable:PROMOL</action>
	     <action>if false disable:RESDENS</action>
	     <action>if true enable:PLOT_ANGS</action>
	     <action>if false disable:PLOT_ANGS</action>
	     <action>if true enable:USESEPARATION</action>
	     <action>if false disable:USESEPARATION</action>
	     <action>if true enable:USEALLPOINTS</action>
	     <action>if false disable:USEALLPOINTS</action>
	     <action>if true enable:USECENTER</action>
	     <action>if false disable:USECENTER</action>
	    </checkbox>
	   </hbox> 

	   <hbox>
	    <text xalign="0" use-markup="true" wrap="true"justify="1" space-fill="True"  space-expand="True"><label>Please select the property to plot:</label></text>
	   </hbox> 

	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>deformation_density</label>
	     <variable>DEFDEN</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>dft_xc_potential</label>
	     <variable>DFTXCPOT</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>electron_density</label>
	     <variable>DENS</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>laplacian</label>
	     <variable>LAPL</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>negative_laplacian</label>
	     <variable>NEGLAPL</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>promolecule_density</label>
	     <variable>PROMOL</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 

	   <hbox>
	    <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
  	     <label>residual_density_map</label>
	     <variable>RESDENS</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 

	   <hseparator></hseparator>

	   <hbox>
	    <checkbox active="false" sensitive="false" space-fill="True"  space-expand="True">
  	     <label>Cube file in Angstroms</label>
	     <variable>PLOT_ANGS</variable>		
	     <default>false</default>
	    </checkbox>
	   </hbox> 


	  <hbox space-expand="false" space-fill="false" >

	    <checkbox active="false" sensitive="false" wrap="false" space-expand="FALSE" space-fill="false">
  	     <label>Use desired point separation (in Angstrom)</label>
	     <variable>USESEPARATION</variable>		
	     <default>false</default>
	     <action>if true enable:SEPARATION</action>
	     <action>if false disable:SEPARATION</action>
	     <action>if true disable:USEALLPOINTS</action>
	     <action>if false enable:USEALLPOINTS</action>
	    </checkbox>

	   <hbox space-expand="true" space-fill="true" >
	    <entry space-expand="true" sensitive="false">
	     <variable>SEPARATION</variable>
	    </entry>
	   </hbox>
	   </hbox>

	  <hbox space-expand="false" space-fill="false" >

	    <checkbox active="false" sensitive="false" wrap="false" space-expand="FALSE" space-fill="false">
  	     <label>use number of points in X, Y and Z (in Angstrom)</label>
	     <variable>USEALLPOINTS</variable>		
	     <default>false</default>
	     <action>if true enable:PTSX</action>
	     <action>if false disable:PTSX</action>
	     <action>if true enable:PTSY</action>
	     <action>if false disable:PTSY</action>
	     <action>if true enable:PTSZ</action>
	     <action>if false disable:PTSZ</action>
	     <action>if true disable:USESEPARATION</action>
	     <action>if false enable:USESEPARATION</action>
	    </checkbox>

	   <hbox space-expand="true" space-fill="true" >
	    <entry space-expand="true" sensitive="false">
	     <default>10</default>
	     <variable>PTSX</variable>
	    </entry>
	    <entry space-expand="true" sensitive="false">
	     <default>10</default>
	     <variable>PTSY</variable>
	    </entry>
	    <entry space-expand="true" sensitive="false">
	     <default>10</default>
	     <variable>PTSZ</variable>
	    </entry>
	   </hbox>
	   </hbox>

	  <hbox space-expand="false" space-fill="false" >

	    <checkbox active="false" sensitive="false" wrap="false" space-expand="FALSE" space-fill="false">
  	     <label>use cube center on atom number</label>
	     <variable>USECENTER</variable>		
	     <default>false</default>
	     <action>if true enable:CENTERATOM</action>
	     <action>if false disable:CENTERATOM</action>
	     <action>if true enable:XAXIS</action>
	     <action>if false disable:XAXIS</action>
	     <action>if true enable:YAXIS</action>
	     <action>if false disable:YAXIS</action>
	     <action>if true enable:WIDTHX</action>
	     <action>if false disable:WIDTHX</action>
	     <action>if true enable:WIDTHY</action>
	     <action>if false disable:WIDTHY</action>
	     <action>if true enable:WIDTHZ</action>
	     <action>if false disable:WIDTHZ</action>
	    </checkbox>

	   <hbox space-expand="true" space-fill="true" >
	    <entry space-expand="true" sensitive="false">
	     <default>1</default>
	     <variable>CENTERATOM</variable>
	    </entry>
	   </hbox>
	   </hbox>

	  <hbox space-expand="false" space-fill="false" >
	   <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>X axis defined by atoms number</label></text>
	   <hbox space-expand="true" space-fill="true" >
	    <entry space-expand="true" sensitive="false">
	     <default>1 2</default>
	     <variable>XAXIS</variable>
	    </entry>
	   </hbox>
	   </hbox>

	  <hbox space-expand="false" space-fill="false" >
	   <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>Y axis defined by atoms number</label></text>
	   <hbox space-expand="true" space-fill="true" >
	    <entry space-expand="true" sensitive="false">
	     <default>1 3</default>
	     <variable>YAXIS</variable>
	    </entry>
	   </hbox>
	   </hbox>

	  <hbox space-expand="false" space-fill="false" >
	   <text text-xalign="0" use-markup="true" wrap="false" space-expand="FALSE" space-fill="false"><label>width in X, Y and Z (in Angstrom)</label></text>
	   <hbox space-expand="true" space-fill="true" >
	    <entry space-expand="true" sensitive="false">
	     <default>10</default>
	     <variable>WIDTHX</variable>
	    </entry>
	    <entry space-expand="true" sensitive="false">
	     <default>10</default>
	     <variable>WIDTHY</variable>
	    </entry>
	    <entry space-expand="true" sensitive="false">
	     <default>10</default>
	     <variable>WIDTHZ</variable>
	    </entry>
	   </hbox>
	   </hbox>

	  </frame>
	 </vbox>

	 </notebook>

	   <hbox>
	    <button ok>
	    </button>
	    <button cancel>
	    </button>
	   </hbox>

         </vbox>

	</window>
'
gtkdialog --program=MAIN_DIALOG > job_options.txt

source ./job_options.txt

CIF="$(echo $CIF | awk -F "/" '{print $NF}')"
INITADPFILE="$(echo $INITADPFILE | awk -F "/" '{print $NF}')"
HKL="$(echo $HKL | awk -F "/" '{print $NF}')"
#$TONTO="$(echo $TONTO | awk -F "/" '{print $NF}')"

sed -i '/INITADPFILE=/c\INITADPFILE=\".\/'$INITADPFILE'"' job_options.txt
sed -i '/CIF=/c\CIF=\".\/'$CIF'"' job_options.txt
sed -i '/HKL=/c\HKL=\".\/'$HKL'"' job_options.txt

#sed -i "12s/CIF=.*/CIF=\".\/$CIF\"/g" job_options.txt doesnt work with the source
#sed -i "34s/HKL=.*/HKL=\".\/$HKL\"/g" job_options.txt doesnt work with the source
#sed -i "46s/TONTO=.*/TONTO=\".\/$TONTO\"/g" job_options.txt doesnt work with the source

source ./job_options.txt

#rm job_options.txt

echo "" > $JOBNAME.lst
if [[ -z "$SCFCALCPROG" ]]; then
	SCFCALCPROG="Gaussian"
	echo "SCFCALCPROG=\"$SCFCALCPROG\"" >> job_options.txt
fi

if [ "$GAUSGEN" = "true" ]; then
    BASISSETG="gen"
    zenity --entry --title="New basis set" --text="Enter or paste the basis set in the gaussian format as: \n !!NO EMPTY LINE!! \n C 0 \n S 5 \n exponent1 coefficient1 \n exponent2 coefficient2 \n exponent3 coefficient3 \n exponent4 coefficient4 \n exponent5 coefficient5 \n **** \n !!NO EMPTY LINE!! \n (Repeat this for all shells and all elements) " > basis_gen.txt
    sed -i '/BASISSETG=/c\BASISSETG=\"'$BASISSETG'"' job_options.txt
fi

if [ "$GAUSSREL" = "true" ]; then
    INT="int=dkh"
    echo "INT=\"$INT\"" >> job_options.txt
fi

if [[ "$DISP" = "yes" && "$EXIT" = "OK" ]]; then
	zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	while [ $? -eq 1 ]; do 
		zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	done
fi

if [[ "$SCFCALCPROG" == "elmodb" && "$EXIT" == "OK" ]]; then
	if [[ ! -f "$( echo $CIF | awk -F "/" '{print $NF}' )" ]]; then
		cp $CIF .
	fi
	PDB=$( echo $CIF | awk -F "/" '{print $NF}' ) 
	echo "PDB=\"$PDB\"" >> job_options.txt
	if [[ ! -z "$MANUALRESIDUE" ]]; then 
		if [[ ! -f TAILORED ]]; then
			echo "$MANUALRESIDUE" > TAILORED
		fi
	else 
		echo " 
ALE   0   17  .t.        !Input for the first tailor-made residue 
	
CA        1    1   .f.     N   CA  C     
N         1    1   .f.     CA  N   H1     
C         1    1   .f.     CA  C   O     
O         3    1   .f.     C   O   OXT     
OXT       3    1   .f.     C   OXT O
CB        1    1   .f.     CA  CB  HB1   
CA_HA     1    2   .f.     CA  HA  C    
CA_N      1    2   .f.     CA  N   HA     
N_H1      1    2   .f.     N   H1  CA
N_H2      1    2   .f.     N   H2  CA
N_H3      1    2   .f.     N   H3  CA  
CA_C      1    2   .f.     CA  C   O     
C_O_OXT   4    3   .f.     C   O   OXT      
CA_CB     1    2   .f.     CA  CB  C    
CB_HB1    1    2   .f.     CB  HB1 CA   
CB_HB2    1    2   .f.     CB  HB2 CA   
CB_HB3    1    2   .f.     CB  HB3 CA 
 " > TAILORED
	fi

	if [[ ! -z "$SSBONDATOMS" ]]; then 
		if [[ ! -f DISSBONDS ]]; then
			echo "$SSBONDATOMS" > DISSBONDS
		fi
	else 
		echo " 
   3  40
   4  32
  16  26
 " > DISSBONDS
	fi
	if [[ ! -f "tonto.cell" ]]; then
		#extracting information from pdb file into new jobname.pdb file (only for elmodb)
		# is tehre a cell in the pdb?
		if [[ ! -z $(awk '$1 ~ /CRYST1/ {print $0}'  $PDB) ]]; then
			CELLA=$(awk '$1 ~ /CRYST1/ {print $2}'  $PDB)
			CELLB=$(awk '$1 ~ /CRYST1/ {print $3}'  $PDB)
			CELLC=$(awk '$1 ~ /CRYST1/ {print $4}'  $PDB)
			CELLALPHA=$(awk '$1 ~ /CRYST1/ {print $5}'  $PDB)
			CELLBETA=$(awk '$1 ~ /CRYST1/ {print $6}'  $PDB)
			CELLGAMMA=$(awk '$1 ~ /CRYST1/ {print $7}'  $PDB)
			SPACEGROUP=$(awk '$1 ~ /CRYST1/ {print $0}' $PDB | awk ' {print substr($0,index($0,$8),--NF)}')
	  		echo "      spacegroup= { hermann_mauguin_symbol= '$SPACEGROUP' }" > tonto.cell
			echo "" >> tonto.cell
			echo "      unit_cell= {" >> tonto.cell
			echo "" >> tonto.cell
			echo "         angles=       $CELLALPHA   $CELLBETA   $CELLGAMMA   Degree" >> tonto.cell
			echo "         dimensions=   $CELLA   $CELLB   $CELLC   Angstrom" >> tonto.cell
			echo "" >> tonto.cell
			echo "      }" >> tonto.cell
			echo "" >> tonto.cell
			echo "      REVERT" >> tonto.cell
		else
			SPACEGROUPMENU
			CELLA=$(awk -F'|' '{print $1}'  crystal_data.txt )
			CELLB=$(awk -F'|' '{print $2}'  crystal_data.txt )
			CELLC=$(awk -F'|' '{print $3}'  crystal_data.txt )
			CELLALPHA=$(awk -F'|' '{print $4}'  crystal_data.txt )
			CELLBETA=$(awk -F'|' '{print $5}'  crystal_data.txt )
			CELLGAMMA=$(awk -F'|' '{print $6}'  crystal_data.txt )
			SPACEGROUP=$(cat spacegroup.txt | awk -F'=' '{print $3}' )
			rm spacegroup.txt
			echo "      spacegroup= { hall_symbol= '$SPACEGROUP' }" > tonto.cell
			echo "" >> tonto.cell
			echo "      unit_cell= {" >> tonto.cell
			echo "" >> tonto.cell
			echo "         angles=       $CELLALPHA   $CELLBETA   $CELLGAMMA   Degree" >> tonto.cell
			echo "         dimensions=   $CELLA   $CELLB   $CELLC   Angstrom" >> tonto.cell
			echo "" >> tonto.cell
			echo "      }" >> tonto.cell
			echo "" >> tonto.cell
			echo "      REVERT" >> tonto.cell
		fi
		# are there more lines in the pdb then the ATOM lines?
		if [[ ! -z $(awk '$1 !~ /ATOM/ && ! /HETATM/ && ! /END/ {print $0}'  $PDB) ]]  ; then
			awk '$1 ~ /ATOM/ {print $0}'  $PDB > $JOBNAME.cut.pdb
			awk '$1 ~ /HETATM/ {print $0}'  $PDB > $JOBNAME.cut.pdb
			echo "END" >> $JOBNAME.cut.pdb
			if [[ ! -z $(diff -ZB $PDB $JOBNAME.cut.pdb) ]]; then
				PDB=$JOBNAME.cut.pdb	
				echo "PDB=\"$PDB\"" >> job_options.txt
			fi
		fi
	fi
fi

if [ "$EXIT" = "OK" ]; then
	QUEUE
else
	unset MAIN_DIALOG
 	clear
	exit 0
fi

