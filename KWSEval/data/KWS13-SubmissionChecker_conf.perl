$expid_count = 11;
@expid_tag  = ( 'KWS13' ); # should only contain 1 entry
@expid_partition = ( 'conv-dev', 'conv-eval' ); # order is important
@expid_scase = ( 'BaDev', 'BaEval', 'BaSurp' ); # order is important
@expid_task = ( 'KWS', 'STT' ); # order is important
@expid_lp = ( 'FullLP', 'LimitedLP' ); # order is important
@expid_lr = ( 'BaseLR', 'BabelLR', 'OtherLR' ); # order is important
@expid_aud = ( 'NTAR', 'TAR' ); # order is important
@expid_sysid_beg = ( "p-", "c-" ); # order is important

#
@Scase_toSequester = ( $expid_scase[1], $expid_scase[2] );
