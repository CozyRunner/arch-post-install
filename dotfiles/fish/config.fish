# Arch Logo                                                             
set_color normal                                                        
function fish_prompt                                                    
    set_color cyan                                                      
    printf ' '                                                         
    set_color green                                                     
    printf '%s@%s ' (whoami) (hostname -s)                              
    set_color yellow                                                    
    printf '%s ' (basename (prompt_pwd))                                
    set_color normal                                                    
    printf '%s ' (if test (id -u) -eq 0; echo '#'; else; echo '$'; end) 
end
