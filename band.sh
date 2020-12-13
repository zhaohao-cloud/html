#!/bin/bash

#PBS -N zh
#PBS -l nodes=1:ppn=28
#PBS -q batch
#PBS -V
# /home/share/software/vasp.5.4.1.05Feb16/intel/clean/vasp_std
submit() {
  local dir
  dir=$1
  if test -z "${dir}"; then
    cd "${PBS_O_WORKDIR}" || exit
  else
    cd "${PBS_O_WORKDIR}"/"${dir}" || exit
  fi
  local NP
  NP=$(cat "$PBS_NODEFILE" | wc -l)
  NN=$(cat "$PBS_NODEFILE" | sort | uniq | tee /tmp/nodes.$$ | wc -l)
  cat "$PBS_NODEFILE" >/tmp/nodefile.$$
  mpirun -genv I_MPI_DEVICE ssm -machinefile /tmp/nodefile.$$ -n "$NP" /home/share/software/vasp.5.4.1.05Feb16/intel/clean/vasp_std
  rm -rf /tmp/nodefile.$$
  rm -rf /tmp/nodes.$$
}

cd "${PBS_O_WORKDIR}" || exit

#
# 1.structure optimization
#

strpath="struct"
scfpath="scf"
bandpath="band"
mkdir $strpath
cat > INCAR <<!
  INCAR for structure optimization
  ENCUT = 450.000000
  SIGMA = 0.050000
  ADDGRID = T
  LREAL = A
  NELMIN = 5
  EDIFF = 1.00e-06
  EDIFFG = -2.00e-02
  ALGO = N
  #GGA = PE
  PREC = Accurate
  IBRION = 2
  ISIF = 3
  ISMEAR = 0
  NSW = 500
  LCHARG = .FALSE.
  LWAVE = .FALSE.
  LREAL = Auto
!
cat > POSCAR <<!
 MoS2_mp-1023924_primitive
   1.000
    3.1902999878000000    0.0000000000000000    0.0000000000000000
   -1.5951499939000002    2.7628808350999994    0.0000000000000000
    0.0000000000000011    0.0000000000000019   18.1298007965000032
   Mo   S
    1    2
Direct
    0.0000000000000000    0.0000000000000000    0.5000049995000000    Mo1
    0.3333300050000000    0.6666700240000000    0.5863149985000000     S1
    0.3333300050000000    0.6666700240000000    0.4136850015000000     S2
!
vaspkit -task 102 -kpr 0.04
mv INCAR KPOINTS POSCAR POTCAR -t $strpath
submit $strpath

#
# 2.scf
#

mv CONTCAR ../POSCAR
cd ..
mkdir $scfpath
cat > INCAR <<!
  INCAR for scf
  ENCUT = 500.000000
  SIGMA = 0.010000
  #EDIFFG = -2.00e-02
  ALGO = Normal
  #GGA = PE
  PREC = Accurate
  #IBRION = -1
  ISMEAR = 0
  ISYM = 2
  LORBIT = 11
  NSW = 0
  #LAECHG = .TRUE.
  LCHARG = .TRUE.
  LVHAR = T
  LWAVE = .TRUE.
  LREAL = Auto
!
vaspkit -task 102 -kpr 0.04
mv INCAR KPOINTS POSCAR POTCAR -t $scfpath
submit $scfpath

#
# 3.band
#

mv CHGCAR POSCAR POTCAR WAVECAR -t ..
cd ..
mkdir $bandpath
cat > INCAR <<!
  INCAR for band structure
  ENCUT = 500.000000
  SIGMA = 0.010000
  #EDIFFG = -2.00e-02
  ALGO = Normal
  #GGA = PE
  PREC = Accurate
  #IBRION = -1
  ICHARG = 11
  ISMEAR = 0
  ISYM = 2
  LORBIT = 11
  NSW = 0
  #LAECHG = .TRUE.
  LCHARG = .TRUE.
  LVHAR = .TRUE.
  LWAVE = .TRUE.
  LREAL = Auto
!
vaspkit -task 302
cp KPATH.in KPOINTS
mv INCAR KPOINTS POSCAR POTCAR CHGCAR WAVECAR -t $bandpath
submit $bandpath

#
# 4.Post-process Band Structure
#
echo -e "211\n" | vaspkit
mv ../band.py .
NP=$(cat "$PBS_NODEFILE" | wc -l)
NN=$(cat "$PBS_NODEFILE" | sort | uniq | tee /tmp/nodes.$$ | wc -l)
cat "$PBS_NODEFILE" >/tmp/nodefile.$$
mpirun -genv I_MPI_DEVICE ssm -machinefile /tmp/nodefile.$$ -n "$NP" python band.py
rm -rf /tmp/nodefile.$$
rm -rf /tmp/nodes.$$
