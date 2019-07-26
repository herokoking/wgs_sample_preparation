#!/bin/bash

## With GNU Parallel
# ls -1 samples_split/* | parallel -k -j 10 srun -c 4 --mem 20G -p large --time 21-00:00 -J bwaMem -o 10-log_files/bwaMEMsplit_%j.log ./00-scripts/bwa_mem_align_reads_by_n_samples.sh 4 {} \; sleep 0.1 &

## srun
# srun -c 4 --mem 20G -p large --time 21-00:00 -J bwaMem -o 10-log_files/bwaMEMsplit_%j.log ./00-scripts/bwa_mem_align_reads_by_n_samples.sh 4 <SAMPLE_FILE>

# First split sample list to align into different files with:
# cd 04-all_samples
# ls -1 *.fq.gz > ../all_samples_for_alignment.txt
# cd ..
# mkdir samples_split
# split -a 4 -l 100 -d all_samples_for_alignment.txt samples_split/samples_split.

# Global variables
GENOMEFOLDER="03_genome"
GENOME="genome.fasta"
RAWDATAFOLDER="05_trimmed"
ALIGNEDFOLDER="06_aligned"
SAMPLE_FILE="$1"
NCPU=$2

# Test if user specified a number of CPUs
if [[ -z "$NCPU" ]]
then
    NCPU=4
fi

# Load needed modules
module load bwa
module load samtools/1.8

# Index genome if not alread done
#bwa index -p "$GENOMEFOLDER"/"$GENOME" "$GENOMEFOLDER"/"$GENOME"

# Iterate over sequence file pairs and map with bwa
for file in $(ls -1 "$RAWDATAFOLDER"/*_1.trimmed.fastq.gz)
do

cat "$SAMPLE_FILE" |
while read file
do
    # Name of uncompressed file
    file2=$(echo "$file" | perl -pe 's/_1\.trimmed/_2.trimmed/')
    echo "Aligning file $file $file2" 

    name=$(basename "$file")
    name2=$(basename "$file2")
    ID="@RG\tID:ind\tSM:ind\tPL:Illumina"

    # Align reads
    bwa mem -t "$NCPU" -R "$ID" "$GENOMEFOLDER"/"$GENOME" "$RAWDATAFOLDER"/"$name" "$RAWDATAFOLDER"/"$name2" |
    samtools view -Sb -q 10 - > "$ALIGNEDFOLDER"/"${name%.fastq.gz}".bam

    # Sort
    samtools sort --threads "$NCPU" "$ALIGNEDFOLDER"/"${name%.fastq.gz}".bam \
        > "$ALIGNEDFOLDER"/"${name%.fastq.gz}".sorted.bam

    # Index
    samtools index "$ALIGNEDFOLDER"/"${name%.fastq.gz}".sorted.bam

    # Remove unsorted bam file
    rm "$ALIGNEDFOLDER"/"${name%.fastq.gz}".bam
done