; cards.p8
%import diskio
%import sprites
%import textio
%import syslib
%import palette
%zeropage basicsafe
%option no_sysinit

/*  main is commented out, this is intended to be a library included in other Prog8 programs
main {  ; test out the other blocks in this file
    sub start() {
        cards.init(cards.CORNER_TILE)
        deck.init()
        
        deck.shuffle()

        ubyte[7] card
        ubyte i

        card[0] = deck.draw()
        card[1] = deck.draw()
        card[2] = deck.draw()
        card[3] = deck.draw()
        card[4] = deck.draw()
        card[5] = deck.draw()
        card[6] = deck.draw()

        for i in 0 to 6 {
            cards.show(card[i],8+i*11,16,cards.CARD_FACE, false)
        }

        void txt.waitkey()

        for i in 6 downto 0 {
            cards.flip(card[i])
        }

        void txt.waitkey()

         for i in 0 to 6 {
            cards.flip(card[i])
        }

        void txt.waitkey()

        for i in 6 downto 0 {
            cards.hide(card[i])
        }

        tile.exit()
    }
}
*/

cards {
    %option ignore_unused
    const ubyte CORNER_TILE = 0
    const ubyte CORNER_SPRITE = 1
    const ubyte CORNER_TEXT = 2

    const ubyte CARD_WIDTH = 9
    const ubyte CARD_HEIGHT = 14

    const ubyte CARD_FACE = 0
    const ubyte CARD_BACK = 1

    const ubyte CARD_BORDER_COLOR = $1C
    const ubyte CARD_FILL_COLOR   = $12

    ubyte @zp col
    ubyte @zp row
    ubyte @zp ccard    ; current card

    ; each card is a ubyte with the upper nibble being the suit and the lower nibble the rank
    str[] suits = ["","spades","hearts","diamonds","clubs"]
    str[] face = ["","ace","two","three","four","five","six","seven","eight","nine","ten","jack","queen","king"]
    ubyte[81] name_buffer

    ; the index for corner and visible is the card: suit << 4 | rank
    uword[78] corner  = 0       ; upper left corner of the card    
    bool[78]  visible = false
    ubyte     corner_type

    ubyte[] ul_corner = [$0f,
                         $10,
                         $20,
                         $40,
                         $80,$80,$80,$80]
    ubyte[] ur_corner = [$f0,
                         $08,
                         $04,
                         $02,
                         $01,$01,$01,$01]
    ubyte[] ll_corner = [$80,$80,$80,$80,
                         $40,
                         $20,
                         $10,
                         $0f]
    ubyte[] lr_corner = [$01,$01,$01,$01,
                         $02,
                         $04,
                         $08,
                         $f0]

    sub init(ubyte p_corner_type) {
        corner_type = p_corner_type
        sprite.init()
        if corner_tile() {
            tile.init()     
        }
        if corner_text() {
            vera.replace_char($4f, &ul_corner)
            vera.replace_char($50, &ur_corner)
            vera.replace_char($4c, &ll_corner)
            vera.replace_char($7a, &lr_corner)
        }
    }

    sub exit() {
        if corner_tile() tile.exit()
    }

    sub get_corner_type() -> ubyte {
        return corner_type
    }

    sub corner_tile() -> bool {
        return corner_type == CORNER_TILE
    }

    sub corner_sprite() -> bool {
        return corner_type == CORNER_SPRITE
    }

    sub corner_text() -> bool {
        return corner_type == CORNER_TEXT
    }

    sub name(ubyte card) -> uword {
        if card == 0 {
            return "not a card"
        }
        ; build the card name
        void string.copy(face[rank(card)], name_buffer)
        void string.append(name_buffer, " of ")
        void string.append(name_buffer, suits[suit(card)])
        return name_buffer
    }

    sub suit_name(ubyte card) -> uword {
        return suits[card >> 4]
    }

    sub face_name(ubyte card) -> uword {
        return face[card & $0F]
    }

    sub suit(ubyte card) -> ubyte {
        return card >> 4
    }

    sub symbol(ubyte card) -> ubyte {
        when suit(card) {
            1 -> return '\x41'  ; spades
            2 -> return '\x53'  ; hearts
            3 -> return '\x5a'  ; diamonds
            4 -> return '\x58'  ; clubs
        }
    }

    sub color(ubyte card) -> ubyte {
        when suit(card) {
            1 -> return $10  ; spades
            2 -> return $12  ; hearts
            3 -> return $12  ; diamonds
            4 -> return $10  ; clubs
        }
    }

    sub rank(ubyte card) -> ubyte {
        return card & $0F
    }

    sub is_visible(ubyte card) -> bool {
        return visible[card]
    }

    sub face_shown(ubyte card) -> bool {
        col = lsb(corner[card])
        row = msb(corner[card])
        return txt.getchr(col+3,row+1) == $20 
    }

    sub flip(ubyte card) {
        if visible[card] == true {
            col = lsb(corner[card])
            row = msb(corner[card])
            if face_shown(card) {
                ; the face is shown
                show(card,col,row,CARD_BACK, false)
            } else {
                show(card,col,row,CARD_FACE, false)
            }
       }
    }

    sub show(ubyte card, ubyte p_column, ubyte p_row, ubyte p_face, bool overlap) {
;        if visible[card] == true {
;            hide(card)
;        }
        col = p_column
        row = p_row
        corner[card] = mkword(p_row, p_column)
        if corner_tile() outline(card, overlap)
        if corner_sprite() outline_sprite(card, overlap)
        if corner_text() outline_text(card, overlap)
        if p_face == CARD_FACE {
            fill_card(card)
        } else {
            fill_back(card)
        }
        visible[card] = true
    }

    sub hide(ubyte card) {
        if visible[card] == true {
;            &ubyte i      = $0013 ;cx16.r8H
;            &ubyte j      = $0012 ;cx16.r8L
;            &ubyte right  = $0011 ;cx16.r7H
;            &ubyte bottom = $0010 ;cx16.r7L
;            &ubyte clr    = $000F ;cx16.r6H
            ubyte i
            ubyte j
            ubyte right
            ubyte bottom
            ubyte clr

            if cards.rank(card) > 10 {
                sprite.hide_face(card)
            }

            col = lsb(corner[card])
            row = msb(corner[card])

            right  = col + CARD_WIDTH
            bottom = row + CARD_HEIGHT

            clr = txt.getclr(right,bottom)

            ; right edge
            if corner_tile() tile.corner(right,row,tile.CORNER_UPPER_RIGHT,true)
            if corner_sprite() sprite.corner(right,row,sprite.CORNER_UPPER_RIGHT,true)
            if corner_text() txt.setcc2(right,row,$20,clr)
            for i in row+1 to bottom-1 {
                txt.setcc2(right,i,$20,clr)            
            }
            if corner_tile() tile.corner(right,bottom,tile.CORNER_LOWER_RIGHT,true)
            if corner_sprite() sprite.corner(right,bottom,sprite.CORNER_LOWER_RIGHT,true)
            if corner_text() txt.setcc2(right,bottom,$20,clr)

            ; middle ground
            for i in right-1 downto col+1 {
                txt.setcc2(i,row,$20,clr)
                for j in row+1 to bottom-1 {
                    txt.setcc2(i,j,$20,clr)
                }    
                txt.setcc2(i,bottom,$20,clr)
            }

            ; left edge
            if corner_tile() tile.corner(col,row,tile.CORNER_UPPER_LEFT,true)
            if corner_sprite() sprite.corner(col,row,sprite.CORNER_UPPER_LEFT,true)
            if corner_text() txt.setcc2(col,row,$20,clr)
            ; fill left edge
            for i in row+1 to bottom-1 {
                txt.setcc2(col,i,$20,clr)            
            }
            if corner_tile() tile.corner(col,bottom,tile.CORNER_LOWER_LEFT,true)
            if corner_sprite() sprite.corner(col,bottom,sprite.CORNER_LOWER_LEFT,true)
            if corner_text() txt.setcc2(col,bottom,$20,clr)

            visible[card] = false
        }
    }

    sub hide_color(ubyte card, ubyte clr) {
            &ubyte right  = $0011 ;cx16.r7H
            &ubyte bottom = $0010 ;cx16.r7L
         
            col = lsb(corner[card])
            row = msb(corner[card])

            right  = col + CARD_WIDTH
            bottom = row + CARD_HEIGHT

            txt.setcc2(right,bottom,$20,clr)

            hide(card)
    }

    sub outline(ubyte card, bool overlap) {
        &ubyte i      = $0013 ;cx16.r8H
        &ubyte j      = $0012 ;cx16.r8L
        &ubyte right  = $0011 ;cx16.r7H
        &ubyte bottom = $0010 ;cx16.r7L

        right  = col + CARD_WIDTH
        bottom = row + CARD_HEIGHT

        ; left edge
        tile.corner(col,row,tile.CORNER_UPPER_LEFT,false)
        ; fill left edge
        for i in row+1 to bottom-1 {
            txt.setcc2(col,i,$65,CARD_BORDER_COLOR)            
            if overlap tile.corner(col,i,0,true)
        }
        tile.corner(col,bottom,tile.CORNER_LOWER_LEFT,false)

        ; middle ground
        for i in col+1 to right-1 {
            txt.setcc2(i,row,$63,CARD_BORDER_COLOR)
            if overlap tile.corner(i,row,0,true)
            for j in row+1 to bottom-1 {
                txt.setcc2(i,j,$20,CARD_FILL_COLOR)
            }    
            txt.setcc2(i,bottom,$64,CARD_BORDER_COLOR)
            if overlap tile.corner(i,bottom,0,true)
        }

        ; right edge
        tile.corner(right,row,tile.CORNER_UPPER_RIGHT,false)
        for i in row+1 to bottom-1 {
            txt.setcc2(right,i,$67,CARD_BORDER_COLOR)            
            if overlap tile.corner(right,i,0,true)
        }
        tile.corner(right,bottom,tile.CORNER_LOWER_RIGHT,false)
    }

    sub outline_sprite(ubyte card, bool overlap) {
        &ubyte i      = $0013 ;cx16.r8H
        &ubyte j      = $0012 ;cx16.r8L
        &ubyte right  = $0011 ;cx16.r7H
        &ubyte bottom = $0010 ;cx16.r7L

        right  = col + CARD_WIDTH
        bottom = row + CARD_HEIGHT

        ; left edge
        sprite.corner(col,row,tile.CORNER_UPPER_LEFT,false)
        ; fill left edge
        for i in row+1 to bottom-1 {
            txt.setcc2(col,i,$65,CARD_BORDER_COLOR)            
            if overlap sprite.corner(col,i,0,true)
        }
        sprite.corner(col,bottom,tile.CORNER_LOWER_LEFT,false)

        ; middle ground
        for i in col+1 to right-1 {
            txt.setcc2(i,row,$63,CARD_BORDER_COLOR)
            if overlap sprite.corner(i,row,0,true)
            for j in row+1 to bottom-1 {
                txt.setcc2(i,j,$20,CARD_FILL_COLOR)
            }    
            txt.setcc2(i,bottom,$64,CARD_BORDER_COLOR)
            if overlap sprite.corner(i,bottom,0,true)
        }

        ; right edge
        sprite.corner(right,row,tile.CORNER_UPPER_RIGHT,false)
        for i in row+1 to bottom-1 {
            txt.setcc2(right,i,$67,CARD_BORDER_COLOR)            
            if overlap sprite.corner(right,i,0,true)
        }
        sprite.corner(right,bottom,tile.CORNER_LOWER_RIGHT,false)
    }

    sub outline_text(ubyte card, bool overlap) {
        &ubyte i      = $0013 ;cx16.r8H
        &ubyte j      = $0012 ;cx16.r8L
        &ubyte right  = $0011 ;cx16.r7H
        &ubyte bottom = $0010 ;cx16.r7L

        right  = col + CARD_WIDTH
        bottom = row + CARD_HEIGHT

        ; left edge
        txt.setcc2(col,row,$4f,CARD_BORDER_COLOR)
        ; fill left edge
        for i in row+1 to bottom-1 {
            txt.setcc2(col,i,$65,CARD_BORDER_COLOR)            
        }
        txt.setcc2(col,bottom,$4c,CARD_BORDER_COLOR)

        ; middle ground
        for i in col+1 to right-1 {
            txt.setcc2(i,row,$63,CARD_BORDER_COLOR)
            for j in row+1 to bottom-1 {
                txt.setcc2(i,j,$20,CARD_FILL_COLOR)
            }    
            txt.setcc2(i,bottom,$64,CARD_BORDER_COLOR)
        }

        ; right edge
        txt.setcc2(right,row,$50,CARD_BORDER_COLOR)
        for i in row+1 to bottom-1 {
            txt.setcc2(right,i,$67,CARD_BORDER_COLOR)            
        }
        txt.setcc2(right,bottom,$7a,CARD_BORDER_COLOR)
    }

    sub fill_card(ubyte card) {
        const ubyte col1 = 2
        const ubyte col2 = 4
        const ubyte col3 = 6
        const ubyte row1 = 4
        const ubyte row2 = 6
        const ubyte row3 = 8
        const ubyte row4 = 10
        const ubyte row11 = 5
        const ubyte row12 = 7
        const ubyte row13 = 9

        &ubyte clr    = $000F ;cx16.r6H
        &ubyte chr    = $000E ;cx16.r6L
        &ubyte symbl = $000D ;cx16.r5H

        col = lsb(corner[card])
        row = msb(corner[card])

        clr = color(card)
        ; draw the suit symbol on the face of the card
        symbl = symbol(card)

        when rank(card) {
            1 -> chr = $01  ; A
            10 -> { chr = $31 txt.setcc2(col+2,row+1,$30,clr) }
            11 -> chr = $0A ; J
            12 -> chr = $11 ; Q
            13 -> chr = $0B ; K
            else -> chr = rank(card) | $30
        }
        txt.setcc2(col+1,row+1,chr,clr)
        txt.setcc2(col+1,row+2,symbl,clr)

        when rank(card) {
            1 ->  { 
                bigletters.ace(col+1,row+4, card)
;                at_pos(col2, row12) 
                }
            2 ->  { 
                at_pos(col2, row11) 
                at_pos(col2, row13) 
                }
            3 ->  {
                at_pos(col2, row1)
                at_pos(col2, row12)
                at_pos(col2, row4)
                }
            4->  {
                at_pos(col1, row1)
                at_pos(col3, row1)
                at_pos(col1, row4)
                at_pos(col3, row4)
                }
            5->  {
                at_pos(col1, row1)
                at_pos(col3, row1)
                at_pos(col2, row12)
                at_pos(col1, row4)
                at_pos(col3, row4)
                }
            6->  {
                at_pos(col1, row1)
                at_pos(col3, row1)
                at_pos(col1, row12)
                at_pos(col3, row12)
                at_pos(col1, row4)
                at_pos(col3, row4)
                }
            7->  {
                at_pos(col1, row1)
                at_pos(col3, row1)
                at_pos(col1, row12)
                at_pos(col3, row12)
                at_pos(col2, row13)
                at_pos(col1, row4)
                at_pos(col3, row4)
                }
            8->  {
                at_pos(col1, row1)
                at_pos(col3, row1)
                at_pos(col2, row11)
                at_pos(col1, row12)
                at_pos(col3, row12)
                at_pos(col2, row13)
                at_pos(col1, row4)
                at_pos(col3, row4)
                }
            9->  {
                at_pos(col1, row1)
                at_pos(col1, row2)
                at_pos(col1, row3)
                at_pos(col1, row4)

                at_pos(col2, row12)

                at_pos(col3, row1)
                at_pos(col3, row2)
                at_pos(col3, row3)
                at_pos(col3, row4)
                }
            10 -> {
                at_pos(col1, row1)
                at_pos(col1, row2)
                at_pos(col1, row3)
                at_pos(col1, row4)

                at_pos(col2, row11)
                at_pos(col2, row13)

                at_pos(col3, row1)
                at_pos(col3, row2)
                at_pos(col3, row3)
                at_pos(col3, row4)
                }
            ; the jack, queen and king get sprites, lucky cards, all worth zero in this game
            11,12,13 -> {
                sprite.show(card, col+1, row+4)    
                }    
        }

        sub at_pos(ubyte col_p, ubyte row_p) {
            txt.setcc2(col+col_p, row+row_p, symbl, clr)
        }    
    }   

    sub fill_back(ubyte card) {
        &ubyte i      = $0013 ;cx16.r8H
        &ubyte j      = $0012 ;cx16.r8L
        &ubyte right  = $0011 ;cx16.r7H
        &ubyte bottom = $0010 ;cx16.r7L

        right  = col + CARD_WIDTH
        bottom = row + CARD_HEIGHT

        if cards.rank(card) > 10 {
            sprite.hide_face(card)
        }

        ; fill in the back
        for i in right-1 downto col+1 {
            for j in row+1 to bottom-1 {
                txt.setcc2(i,j,$57,$E6)  ; circles in blue/light blue
            }    
        }
    }

}

deck {
    %option ignore_unused

    const ubyte DECK_SIZE = 52
    const ubyte LAST_CARD = $00

    ubyte first_index
    ubyte second_index
    ubyte[DECK_SIZE] contents

    ; zp temp variables, reused R15 - R14
    &ubyte i = $20              ; &cx16.r15H
    &ubyte j = $21              ; &cx16.r15L
    &ubyte index = $1E          ; cx16.r14L
    &ubyte card  = $18          ; cx16.r14H

    sub init() {
        deck.new_deck()
    }

    sub new_deck() {
        ; put all 52 cards in the deck, new deck order
        index = 0
        for i in $10 to $40 step $10 {
            for j in 1 to 13 {
                card = i | j
                contents[index] = card
                index++
            }
        }
        first_index = DECK_SIZE
        second_index = 1
    }

    sub shuffle() {
        ; much depends on random ordering, use entropy to start the sequence
        ; set_random_seeds()
        %asm {{
            jsr cx16.entropy_get
            ; AY already contains the first seed
            stx cx16.r0L         ; R0 for the second seed    
            sty cx16.r0H
            jsr math.rndseed
        }}


        ; shuffle the cards now with Fisher-Yates algorithm
        repeat 3 {
            ; shuffle last down to first
            for i in DECK_SIZE - 1 downto 1 {
                j = math.rnd() % i
                card = pokemon(&contents+j,contents[i])
                contents[i] = card
            }
            ; shuffle first up to last
            for i in 0 to DECK_SIZE - 2 {
                j = math.rnd() % (DECK_SIZE - i) + i
                card = pokemon(&contents+j,contents[i])
                contents[i] = card
            }
        }
    }

    sub cut(ubyte idx) {
        ; cut the cards at the idx
        first_index = DECK_SIZE
        first_index -= idx
        second_index = DECK_SIZE 
    }

    sub draw() -> ubyte {     
        if first_index == 0 {        
            second_index--
            if second_index == 0 {
                return $00
            }
            return contents[second_index]
        }
        first_index--
        return contents[first_index]
    }

    sub card_at(ubyte idx) -> ubyte {
        return contents[idx]
    }
}

vera {
    %option ignore_unused

    ; the stride and bank make up ADDR_H
    const ubyte STRIDE_0   = %0000_0000
    const ubyte STRIDE_1   = %0001_0000
    const ubyte STRIDE_2   = %0010_0000
    const ubyte STRIDE_4   = %0011_0000
    const ubyte STRIDE_8   = %0100_0000
    const ubyte STRIDE_16  = %0101_0000
    const ubyte STRIDE_32  = %0110_0000
    const ubyte STRIDE_64  = %0111_0000
    const ubyte STRIDE_128 = %1000_0000
    const ubyte STRIDE_256 = %1001_0000
    const ubyte STRIDE_512 = %1010_0000
    const ubyte STRIDE_40  = %1011_0000
    const ubyte STRIDE_80  = %1100_0000
    const ubyte STRIDE_160 = %1101_0000
    const ubyte STRIDE_320 = %1110_0000
    const ubyte STRIDE_640 = %1111_0000

    const ubyte STRIDE_INC = %0000_0000
    const ubyte STRIDE_DEC = %0000_1000
    
    const ubyte STRIDE_INC_1    = STRIDE_1   | STRIDE_INC
    const ubyte STRIDE_INC_2    = STRIDE_2   | STRIDE_INC
    const ubyte STRIDE_INC_4    = STRIDE_4   | STRIDE_INC
    const ubyte STRIDE_INC_8    = STRIDE_8   | STRIDE_INC
    const ubyte STRIDE_INC_16   = STRIDE_16  | STRIDE_INC
    const ubyte STRIDE_INC_32   = STRIDE_32  | STRIDE_INC
    const ubyte STRIDE_INC_64   = STRIDE_64  | STRIDE_INC
    const ubyte STRIDE_INC_128  = STRIDE_128 | STRIDE_INC
    const ubyte STRIDE_INC_256  = STRIDE_256 | STRIDE_INC
    const ubyte STRIDE_INC_512  = STRIDE_512 | STRIDE_INC
    const ubyte STRIDE_INC_40   = STRIDE_40  | STRIDE_INC
    const ubyte STRIDE_INC_80   = STRIDE_80  | STRIDE_INC
    const ubyte STRIDE_INC_160  = STRIDE_160 | STRIDE_INC
    const ubyte STRIDE_INC_320  = STRIDE_320 | STRIDE_INC
    const ubyte STRIDE_INC_640  = STRIDE_640 | STRIDE_INC

    const ubyte STRIDE_DEC_1    = STRIDE_1   | STRIDE_DEC
    const ubyte STRIDE_DEC_2    = STRIDE_2   | STRIDE_DEC
    const ubyte STRIDE_DEC_4    = STRIDE_4   | STRIDE_DEC
    const ubyte STRIDE_DEC_8    = STRIDE_8   | STRIDE_DEC
    const ubyte STRIDE_DEC_16   = STRIDE_16  | STRIDE_DEC
    const ubyte STRIDE_DEC_32   = STRIDE_32  | STRIDE_DEC
    const ubyte STRIDE_DEC_64   = STRIDE_64  | STRIDE_DEC
    const ubyte STRIDE_DEC_128  = STRIDE_128 | STRIDE_DEC
    const ubyte STRIDE_DEC_256  = STRIDE_256 | STRIDE_DEC
    const ubyte STRIDE_DEC_512  = STRIDE_512 | STRIDE_DEC
    const ubyte STRIDE_DEC_40   = STRIDE_40  | STRIDE_DEC
    const ubyte STRIDE_DEC_80   = STRIDE_80  | STRIDE_DEC
    const ubyte STRIDE_DEC_160  = STRIDE_160 | STRIDE_DEC
    const ubyte STRIDE_DEC_320  = STRIDE_320 | STRIDE_DEC
    const ubyte STRIDE_DEC_640  = STRIDE_640 | STRIDE_DEC

    const ubyte BANK_0     = %0000_0000
    const ubyte BANK_1     = %0000_0001

    const ubyte SPRITES_ENABLE = %0100_0000
    const uword SPRITE_REGS = $FC00    ; actually $1FC00

    const uword SCREEN_CODE_BASE = $F000 ; actually $1F000

    asmsub setaddr(ubyte stride_bank @R0, uword addr @R1) {
        %asm{{
            lda cx16.r0L     ; delta forward or back in top 4 bits
            sta cx16.VERA_ADDR_H
            lda cx16.r1H
            sta cx16.VERA_ADDR_M
            lda cx16.r1L
            sta cx16.VERA_ADDR_L
            rts
        }}
    }

    asmsub setdata0(ubyte stride_bank @R0, uword addr @R1) {
        %asm{{
            stz cx16.VERA_CTRL
            jmp p8s_setaddr
        }}
    }

    asmsub setdata1(ubyte stride_bank @R0, uword addr @R1) {
        %asm{{
            lda #$01
            sta cx16.VERA_CTRL
            jmp p8s_setaddr
        }}
    }

    sub get_sprite_address(uword sprite_index) -> uword {
        return SPRITE_REGS + sprite_index * 8
    }

    sub replace_char(uword chr, uword replacement) {
        setdata0(STRIDE_INC_1 | BANK_1, SCREEN_CODE_BASE + (chr * 8))
        repeat 8 {
            cx16.VERA_DATA0 = @(replacement)
            replacement += 1
        }
    }

}

tile {
    %option ignore_unused

    const ubyte VERA_MAP_HEIGHT_64 = %0100_0000
    const ubyte VERA_MAP_WIDTH_64  = %0001_0000
    const ubyte VERA_MAP_WIDTH_128 = %0010_0000
    const ubyte VERA_COLOR_DEPTH_2 = %0000_0001
    const ubyte VERA_TILE_HEIGHT_8 = %0000_0000
    const ubyte VERA_TILE_WIDTH_8  = %0000_0000

    const ubyte VERA_DC_VIDEO_ENABLE_LAYER_0 = %0001_0000
    const ubyte VERA_DC_VIDEO_ENABLE_LAYER_1 = %0010_0000

    const ubyte VERA_CORNER_TRANSPARENT_INDEX = 0
    const ubyte VERA_CORNER_TILE_INDEX        = 1
    const ubyte VERA_MAP_PALETTE_OFFSET       = $40
    const ubyte VERA_MAP_FLIP_V               = $08
    const ubyte VERA_MAP_FLIP_H               = $04

    const ubyte CORNER_UPPER_LEFT   = 0
    const ubyte CORNER_UPPER_RIGHT  = 1
    const ubyte CORNER_LOWER_LEFT   = 2
    const ubyte CORNER_LOWER_RIGHT  = 3

    const uword CORNER_TILE_ADDRESS = $9800 ; really $19800

    ubyte[] corner_tile = [
        %00000000, %10101010,
        %00000010, %01010101,
        %00001001, %01010101, 
        %00100101, %01010101,
        %10010101, %01010101,
        %10010101, %01010101,
        %10010101, %01010101,
        %10010101, %01010101
    ]

    uword offset
    uword uw_row
    ubyte orient
    ubyte i

    sub init() {
        ; put text below the tiles, by putting the text on layer 0
        cx16.VERA_L0_CONFIG = cx16.VERA_L1_CONFIG
        cx16.VERA_L0_MAPBASE = cx16.VERA_L1_MAPBASE
        cx16.VERA_L0_TILEBASE = cx16.VERA_L1_TILEBASE
        cx16.VERA_DC_VIDEO |= VERA_DC_VIDEO_ENABLE_LAYER_0
        cx16.VERA_DC_VIDEO &= ~VERA_DC_VIDEO_ENABLE_LAYER_1

        ; load the corner tile palette at offset 4 (64 is transparent)
        palette.set_color(65, $fff) ; 1 is white
        palette.set_color(66, $777) ; 2 is medium gray

        ; copy our corner tile into VERA RAM at #13000
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_1,CORNER_TILE_ADDRESS)
        repeat 16 {                 ; tile 0 is transparent
            cx16.VERA_DATA0 = 0
        }
        for i in 0 to 15 {
            cx16.VERA_DATA0 = corner_tile[i] ; tile 1 is the corner tile
        }
        for i in 0 to 15 {
            cx16.VERA_DATA0 = corner_tile[i] ; tile 2 is the corner tile again
        }
        ; set the tile base and size 
         ; 64 x 64 bit tile map 2 bits per pixel
        cx16.VERA_L1_CONFIG = VERA_MAP_HEIGHT_64 | VERA_MAP_WIDTH_128 | VERA_COLOR_DEPTH_2
        ; top six bit of the address | 8x8 tiles
;        cx16.VERA_L1_TILEBASE = ($19800 >> 9) as ubyte | VERA_TILE_HEIGHT_8 | VERA_TILE_WIDTH_8
        cx16.VERA_L1_TILEBASE = $CC as ubyte | VERA_TILE_HEIGHT_8 | VERA_TILE_WIDTH_8

        ; set the tile map at $01000 to $02000
        cx16.VERA_L1_MAPBASE = ($01000 >> 9) as ubyte

        cx16.VERA_L1_HSCROLL_L = 0
        cx16.VERA_L1_HSCROLL_H = 0
        cx16.VERA_L1_VSCROLL_L = 0
        cx16.VERA_L1_VSCROLL_H = 0

        ; clear the tile map
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_0,$1000)
        repeat $4000 {
            cx16.VERA_DATA0 = 0
        }

        cx16.VERA_DC_VIDEO |= VERA_DC_VIDEO_ENABLE_LAYER_1
    }

    sub exit() {
        ; put text below the tiles, by putting the text on layer 0
        cx16.VERA_L1_CONFIG = cx16.VERA_L0_CONFIG
        cx16.VERA_L1_MAPBASE = cx16.VERA_L0_MAPBASE
        cx16.VERA_L1_TILEBASE = cx16.VERA_L0_TILEBASE
        cx16.VERA_DC_VIDEO &= ~VERA_DC_VIDEO_ENABLE_LAYER_0
        cx16.VERA_DC_VIDEO |= VERA_DC_VIDEO_ENABLE_LAYER_1
    }

    sub corner(ubyte col, ubyte row, ubyte orientation, bool erase) {
        uw_row = row
        offset = col * 2
        offset += 256 * uw_row
        offset += $1000

        if erase == true {
            vera.setdata0(vera.STRIDE_0|vera.BANK_0,offset)
            cx16.VERA_DATA0 = VERA_CORNER_TRANSPARENT_INDEX
            return
        }
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_0,offset)
        cx16.VERA_DATA0 = VERA_CORNER_TILE_INDEX

        orient = VERA_MAP_PALETTE_OFFSET
        when orientation {
;            TILE_UPPER_LEFT -> ; do nothing already set
            CORNER_UPPER_RIGHT -> orient |= VERA_MAP_FLIP_H
            CORNER_LOWER_LEFT  -> orient |= VERA_MAP_FLIP_V
            CORNER_LOWER_RIGHT -> orient |= VERA_MAP_FLIP_H | VERA_MAP_FLIP_V
        }
        cx16.VERA_DATA0 = orient
    }
}

sprite {
    %option ignore_unused

    const ubyte CORNER_UPPER_LEFT = 0
    const ubyte CORNER_UPPER_RIGHT = 1
    const ubyte CORNER_LOWER_LEFT = 2
    const ubyte CORNER_LOWER_RIGHT = 3

    const ubyte VERA_ADDR_INC_1   = %0001_0000
    const ubyte VERA_CTRL_USE_DATA0 = 0

    const ubyte VERA_SPRITE_FLIP_BOTH   = %0000_0011
    const ubyte VERA_SPRITE_FLIP_X      = %0000_0001
    const ubyte VERA_SPRITE_FLIP_Y      = %0000_0010

    const ubyte VERA_SPRITE_FRONT       = %0000_1100
    const ubyte VERA_SPRITE_HIDE        = %0000_0000

    const ubyte VERA_SPRITE_SIZE_64_64  = %1111_0000
    const ubyte VERA_SPRITE_SIZE_8_8  = %0000_0000
    
    &word  col      = $000a ;cx16.r4s
    &word  row      = $000c ;cx16.r5s
    &uword vera_ptr = $000e ;cx16.r6
    &uword source   = $0010 ;cx16.r7
    &uword addr     = $0012 ;cx16.r8
    &ubyte pal      = $0014 ;cx16.r9L
    &ubyte i        = $0015 ;cx16.r9H

    ubyte active_sprites

    ubyte[112] corner_col = $FF
    ubyte[112] corner_row = $FF
    ubyte active_corners
    
    ubyte[] corner_sprite = [
        $00,$00,$cc,$cc,
        $00,$0c,$11,$11,
        $00,$c1,$11,$11,
        $0c,$11,$11,$11,
        $c1,$11,$11,$11,
        $c1,$11,$11,$11,
        $c1,$11,$11,$11,
        $c1,$11,$11,$11
    ]

    sub init() {
        ; load the card faces for jack, queen and king at $13000
;        if not diskio.vload_raw("facecards.bin",1,$3100) {
;            txt.print("error loading facecards.bin\n")
;        }
        vera_ptr = $3100
;        vera_ptr = $4100
        source = &included_facecards
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_1,vera_ptr)
        repeat &end_included_facecards - &included_facecards {
            cx16.VERA_DATA0 = @(source)
            source += 1
        }    

        ; load the sprite palette ( only 64 bytes )
        vera_ptr = $FA40
        source = &included_palette
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_1,vera_ptr)
        repeat 64 {
            cx16.VERA_DATA0 = @(source)
            source += 1
        }
        ; add the three more colors for the corner palette
        cx16.VERA_DATA0 = 0         ; index 64 transparent index 0
        cx16.VERA_DATA0 = 0 
        cx16.VERA_DATA0 = lsb($fff) ; index 65 white index 1
        cx16.VERA_DATA0 = msb($fff)
        cx16.VERA_DATA0 = lsb($777) ; index 66 medium gray index 2
        cx16.VERA_DATA0 = msb($777)
    
        ; load the corner sprite at $12000 ( only 32 bytes )
        vera_ptr = $2000
        source = &corner_sprite
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_1,vera_ptr)
        repeat 32 {
            cx16.VERA_DATA0 = @(source)
            source += 1
        }

        cx16.VERA_DC_VIDEO |= %0100_0000 ; enable any sprites

        active_sprites = 14
        active_corners = 0
    }
    
    sub show(ubyte card, ubyte col_c, ubyte row_c) {
        col = col_c  ; set the sprite column
        col *= 8
        row = row_c   ; set the sprite row
        row *= 8

        when cards.suit(card) {  ; set the suit color and addr to the jack
            1 -> { pal = 2 addr = $7900 } ; black custom palette
            2 -> { pal = 3 addr = $6100 } ; red custom palette
            3 -> { pal = 3 addr = $4900 }
            4 -> { pal = 2 addr = $3100 }
;            1 -> { pal = 2 addr = $8900 } ; black custom palette
;            2 -> { pal = 3 addr = $7100 } ; red custom palette
;            3 -> { pal = 3 addr = $5900 }
;            4 -> { pal = 2 addr = $4100 }
        }
        when cards.rank(card) {
                11 -> addr += 0         ; jack needs no advance
                12 -> addr += $800      ; advance past the jack for the queen
                13 -> addr += $1000     ; advance past the jack and queen for the king
                else -> return
        }

        ; fix up the address to the VERA format
        addr >>= 5
        addr |= %0000_1000_0000_0000

        vera_ptr = vera.get_sprite_address(get_sprite_number_face(card))
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_1,vera_ptr)
        cx16.VERA_DATA0 = lsb(addr)
        cx16.VERA_DATA0 = msb(addr)  & $0F
        cx16.VERA_DATA0 = lsb(col)
        cx16.VERA_DATA0 = msb(col)   & $03
        cx16.VERA_DATA0 = lsb(row)
        cx16.VERA_DATA0 = msb(row)   & $03
        cx16.VERA_DATA0 = VERA_SPRITE_FRONT
        cx16.VERA_DATA0 = VERA_SPRITE_SIZE_64_64 | pal
    }

    sub move(ubyte card, uword x, uword y) {
        vera_ptr = vera.get_sprite_address(get_sprite_number_face(card))
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_1,vera_ptr + 2)
        cx16.VERA_DATA0 = lsb(x)
        cx16.VERA_DATA0 = msb(x)   & $03
        cx16.VERA_DATA0 = lsb(y)
        cx16.VERA_DATA0 = msb(y)   & $03
    }

    sub is_corner_sprite(ubyte col_c, ubyte row_c) -> bool {
        for i in 0 to active_corners - 1 {
            if corner_col[i] == col_c {
                if corner_row[i] == row_c {
                    return true
                }
            }
        }
        return false
    }

    sub corner(ubyte col_c, ubyte row_c, ubyte orient, bool b_hide) {
        if b_hide == true {
            if is_corner_sprite(col_c,row_c) {
                hide_sprite(i + active_sprites)
            }
            return
        }

        if is_corner_sprite(col_c, row_c) return

        col = col_c 
        col *= 8
        row = row_c 
        row *= 8
        i = active_corners
        corner_col[i] = col_c
        corner_row[i] = row_c
        active_corners += 1

        ubyte flip = 0 ; no flip
        when orient {
;            CORNER_UPPER_LEFT -> {  ; without flips is set above
;            }
            CORNER_UPPER_RIGHT -> {
                flip = VERA_SPRITE_FLIP_X
            }
            CORNER_LOWER_LEFT -> {
                flip = VERA_SPRITE_FLIP_Y
            }
            CORNER_LOWER_RIGHT -> {
                flip = VERA_SPRITE_FLIP_BOTH
            }
        }

        addr = $0900  ; VERA format for $12000

        vera_ptr = vera.get_sprite_address(i + active_sprites)
        vera.setaddr(vera.STRIDE_INC_1|vera.BANK_1,vera_ptr)
        cx16.VERA_DATA0 = lsb(addr)
        cx16.VERA_DATA0 = msb(addr) & $0F
        cx16.VERA_DATA0 = lsb(col)
        cx16.VERA_DATA0 = msb(col) & $03
        cx16.VERA_DATA0 = lsb(row)
        cx16.VERA_DATA0 = msb(row) & $03
        cx16.VERA_DATA0 = VERA_SPRITE_FRONT | flip
        cx16.VERA_DATA0 = VERA_SPRITE_SIZE_8_8 | 4

        return 
    }

    sub get_sprite_number_face(ubyte card) -> ubyte {
        ubyte s_num = cards.rank(card) - 11
        s_num += (cards.suit(card) - 1) * 3
        s_num += 2   ; get past the mouse pointer
        return s_num
    }

    sub hide_face(ubyte card) {
        hide_sprite(get_sprite_number_face(card))
    }

    sub hide_sprite(ubyte idx) {
        vera_ptr = vera.get_sprite_address(idx) + 6
        vera.setdata0(vera.STRIDE_INC_1|vera.BANK_1,vera_ptr)
        cx16.VERA_DATA0 = VERA_SPRITE_HIDE
    }

    included_facecards:
        %asmbinary "facecards.bin"
    end_included_facecards:

    included_palette:
        %asmbinary "palette.bin"
    end_included_palette:
}

bigletters {
    %option ignore_unused

    const uword CHARSET_OFFSET = $F000  ; bank 1 $1F000

    &uword ptr = $000c      ; cx16.r5
    &ubyte line = $000e     ; cx16.r6L
    &ubyte col = $000f      ; cx16.r6H
    &ubyte row = $0010      ; cx16.r7L
    &ubyte glyph = $0011    ; cx16.r7H
    &ubyte scode = $0012    ; cx16.r8L
    &ubyte clr = $0013      ; cx16.r8H

    sub index_of() -> uword {
        return CHARSET_OFFSET + (( scode as uword ) * 8 )
    }

    sub render() {
        ptr = index_of()
        repeat 8 {
            line = read_line()
            line <<= 1
            repeat 7 {
                line <<= 1
                if_cs {
                    txt.setcc2(col,row,glyph,clr)
                } else {
                    txt.setcc2(col,row,' ',clr)
                }
                col += 1
            }
            col -= 7
            row += 1
            ptr++
        }  
    }

    sub read_line() -> ubyte {
        return cx16.vpeek(1,ptr)
    }

/*
    sub banner(ubyte p_col, ubyte p_row) {
        col = p_col
        row = p_row

        scode = sc:'b'
        glyph = $41     ; spade
        clr   = txt.getclr(col,row)
        clr  &= $F0     ; black
        render()

        col += 7
        row = p_row
        scode = sc:'a'
        glyph = $53     ; heart
        clr   = txt.getclr(col,row)
        clr  &= $F0
        clr  |= $02     ; red
        render()

        col += 7
        row = p_row
        scode = sc:'c'
        glyph = $58     ; club
        clr   = txt.getclr(col,row)
        clr  &= $F0     ; black
        render()

        col += 7
        row = p_row
        scode = sc:'c'
        glyph = $5a     ; diamond
        clr   = txt.getclr(col,row)
        clr  &= $F0
        clr  |= $02     ; red
        render()

        col += 7
        row = p_row
        scode = sc:'a'
        glyph = $41     ; spade
        clr   = txt.getclr(col,row)
        clr  &= $F0     ; black
        render()

        col += 7
        row = p_row
        scode = sc:'r'
        glyph = $53     ; heart
        clr   = txt.getclr(col,row)
        clr  &= $F0
        clr  |= $02     ; red
        render()

        col += 7
        row = p_row
        scode = sc:'a'
        glyph = $58     ; club
        clr   = txt.getclr(col,row)
        clr  &= $F0     ; black
        render()

        col += 6
        row = p_row
        scode = sc:'t'
        glyph = $5a     ; diamond
        clr   = txt.getclr(col,row)
        clr  &= $F0
        clr  |= $02     ; red
        render()

        b_col = p_col
        b_row = p_row
        capture_vsync()
    }
*/
    sub ace(ubyte p_col, ubyte p_row, ubyte p_card) {
        col = p_col
        row = p_row
        clr = txt.getclr(col,row)
        clr &= $F0
        when p_card {
            $11 -> { ; spades
                scode = $41
                glyph = $41
            }
            $21 -> { ; hearts
                scode = $53
                glyph = $53
                clr |= 2
            }
            $31 -> { ; diamonds
                scode = $5A
                glyph = $5A
                clr |= 2
            }
            $41 -> { ; clubs
                scode = $58
                glyph = $58
            }
        }
        render()
    }
/*
    sub capture_vsync() {
        vsync_counter = 0
        sys.set_irq(&handle_vsync)
    }

    sub restore_vsync() {
        sys.restore_irq()
    }

    ubyte vsync_counter
    uword vera_ptr
    ubyte b_row = 0
    ubyte b_col = 0


    sub handle_vsync() {
        vsync_counter += 1
        when vsync_counter {
            30 -> {
                vera_ptr = txt.VERA_TEXTMATRIX_ADDR + b_col + 5 + b_row * 256
                cx16.save_vera_context()
                vera.setdata0(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                vera.setdata1(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                repeat 8 {
                    repeat 64 {
                        when cx16.VERA_DATA0 {
                            $50 -> clr = $5C
                            $5C -> clr = $50
                            $52 -> clr = $5A
                            $5A -> clr = $52
                        }
                        cx16.VERA_DATA1 = clr
                    }
                    vera_ptr += 256
                    vera.setdata0(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                    vera.setdata1(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                }
                cx16.restore_vera_context()
            }
            60 -> {
                vera_ptr = txt.VERA_TEXTMATRIX_ADDR + b_col + 5 + b_row * 256
                cx16.save_vera_context()
                vera.setdata0(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                vera.setdata1(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                repeat 8 {
                    repeat 7 {
                        when cx16.VERA_DATA0 {
                            $50 -> clr = $57
                            $5C -> clr = $57
                            $5A -> clr = $57
                            $5E -> clr = $57
                        }
                        cx16.VERA_DATA1 = clr
                    }
                    vera_ptr += 256
                    vera.setdata0(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                    vera.setdata1(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                }
                cx16.restore_vera_context()
            }
            70,80,90,100,110,120,130 -> {
                vera_ptr = txt.VERA_TEXTMATRIX_ADDR + b_col + 5 + b_row * 256
                vera_ptr += (vsync_counter / 10 - 6) * 14
                cx16.save_vera_context()
                vera.setdata0(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                vera.setdata1(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                repeat 8 {
                    repeat 7 {
                        when cx16.VERA_DATA0 {
                            $50 -> clr = $57
                            $52 -> clr = $57
                            $5A -> clr = $57
                            $5E -> clr = $57
                        }
                        cx16.VERA_DATA1 = clr
                    }
                    vera_ptr += 256
                    vera.setdata0(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                    vera.setdata1(vera.STRIDE_INC_2|vera.BANK_1,vera_ptr)
                }
                cx16.restore_vera_context()
            }
            160 -> {
                banner(b_col, b_row)
                vsync_counter = 0
            }
        }
    }
*/    
}